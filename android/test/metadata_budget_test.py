import importlib.util
import io
import pathlib
import socket
import threading
import unittest
import urllib.response
import zlib
from email.message import Message
from unittest.mock import patch

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'android/app/src/main/python/metadata_budget.py'
spec = importlib.util.spec_from_file_location('metadata_budget_tests', SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MetadataBudgetTest(unittest.TestCase):
    def test_request_limit_stops_additional_metadata_work(self):
        budget = module.MetadataBudget()
        try:
            for _ in range(80):
                budget.request()
            with self.assertRaisesRegex(module.ResourceLimitError, 'too many metadata requests'):
                budget.request()
        finally:
            budget.close()

    def test_oversized_headers_end_the_operation_before_body_processing(self):
        headers = Message()
        headers['X-Large'] = 'x' * 65536
        raw = urllib.response.addinfourl(io.BytesIO(b'unread'), headers, 'https://example.com/', 200)
        budget = module.MetadataBudget()
        try:
            with self.assertRaisesRegex(module.ResourceLimitError, 'headers are too large'):
                module.limit_metadata_response(raw, budget)
            self.assertTrue(raw.closed)
            self.assertEqual(budget.total, 0)
        finally:
            budget.close()

    def test_head_does_not_treat_representation_size_or_encoding_as_a_body(self):
        headers = Message()
        headers['Content-Encoding'] = 'br'
        headers['Content-Length'] = str(1024 * 1024 * 1024)
        raw = urllib.response.addinfourl(io.BytesIO(b''), headers, 'https://example.com/', 200)
        budget = module.MetadataBudget()
        try:
            response = module.limit_metadata_response(raw, budget, head=True)
            self.assertIs(response, raw)
            self.assertEqual(response.read(), b'')
            self.assertEqual(budget.total, 0)
        finally:
            raw.close()
            budget.close()

    def deflate_response(self, content, raw=False):
        compressor = zlib.compressobj(wbits=-zlib.MAX_WBITS if raw else zlib.MAX_WBITS)
        encoded = compressor.compress(content) + compressor.flush()
        headers = Message()
        headers['Content-Encoding'] = 'deflate'
        return urllib.response.addinfourl(io.BytesIO(encoded), headers, 'https://example.com/', 200)

    def test_deflate_and_raw_deflate_still_decode_correctly(self):
        for raw in (False, True):
            with self.subTest(raw=raw):
                budget = module.MetadataBudget()
                response = module.limit_metadata_response(self.deflate_response(b'normal metadata', raw), budget)
                try:
                    self.assertEqual(response.read(), b'normal metadata')
                    self.assertNotIn('Content-Encoding', response.headers)
                finally:
                    response.close()
                    budget.close()

    def test_deflate_expansion_is_bounded(self):
        budget = module.MetadataBudget()
        response = module.limit_metadata_response(self.deflate_response(b'x' * (module.MAX_RESPONSE_BYTES + 1)), budget)
        try:
            with self.assertRaisesRegex(module.ResourceLimitError, 'too large'):
                response.read()
        finally:
            response.close()
            budget.close()

    def test_zero_length_deflate_read_cannot_request_unlimited_output(self):
        budget = module.MetadataBudget()
        raw = self.deflate_response(b'x' * (module.MAX_RESPONSE_BYTES + 1))
        reader = module.DeflateReader(module.LimitedReader(raw, budget, count_total=False))
        try:
            self.assertEqual(reader.read(0), b'')
        finally:
            reader.close()
            budget.close()

    def test_unsupported_encodings_are_rejected_before_decompression(self):
        headers = Message()
        headers['Content-Encoding'] = 'unsupported'
        raw = urllib.response.addinfourl(io.BytesIO(b'not decoded'), headers, 'https://example.com/', 200)
        budget = module.MetadataBudget()
        try:
            with self.assertRaisesRegex(module.ResourceLimitError, 'unsupported compressed'):
                module.limit_metadata_response(raw, budget)
            self.assertTrue(raw.closed)
        finally:
            budget.close()

    def test_expiry_closes_a_blocked_socket_and_releases_its_reader(self):
        left, right = socket.socketpair()
        now = [0.0]
        budget = module.MetadataBudget(clock=lambda: now[0])
        started = threading.Event()
        result = []

        def receive():
            started.set()
            try:
                result.append(left.recv(1))
            except OSError:
                result.append(b'')

        try:
            budget.track(left)
            worker = threading.Thread(target=receive, daemon=True)
            worker.start()
            self.assertTrue(started.wait(2))
            now[0] = 66
            with self.assertRaises(module.ResourceLimitError):
                budget.check()
            worker.join(2)
            self.assertFalse(worker.is_alive())
            self.assertEqual(left.fileno(), -1)
            self.assertEqual(result, [b''])
        finally:
            budget.close()
            left.close()
            right.close()

    def test_close_releases_tracked_sockets_before_a_normal_deadline(self):
        left, right = socket.socketpair()
        budget = module.MetadataBudget()
        try:
            budget.track(left)
            budget.close()
            self.assertEqual(left.fileno(), -1)
            self.assertFalse(budget.sockets)
        finally:
            left.close()
            right.close()

    def test_metadata_reads_do_not_impose_a_video_file_size_limit(self):
        # An extractor may inspect only a prefix of a large media response.
        budget = module.MetadataBudget()
        reader = module.LimitedReader(io.BytesIO(b'x' * (5 * 1024 * 1024)), budget)
        try:
            self.assertEqual(len(reader.read(512)), 512)
            self.assertEqual(budget.total, 512)
        finally:
            reader.close()
            budget.close()

    def test_repeated_validation_reuses_pinned_dns_answers(self):
        records = [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('8.8.8.8', 443))]
        budget = module.MetadataBudget()
        try:
            with patch.object(module.socket, 'getaddrinfo', return_value=records) as lookup:
                self.assertEqual(budget.resolve('example.com', 443), records)
                self.assertEqual(budget.resolve('example.com', 443), records)
                self.assertEqual(lookup.call_count, 1)
        finally:
            budget.close()

    def test_excessive_dns_answers_are_not_cached(self):
        budget = module.MetadataBudget()
        try:
            with patch.object(module.socket, 'getaddrinfo', return_value=[None] * 65):
                with self.assertRaisesRegex(module.ResourceLimitError, 'too many network addresses'):
                    budget.resolve('example.com', 443)
            self.assertFalse(budget.addresses)
        finally:
            budget.close()

    def test_slow_os_dns_can_occupy_at_most_two_helpers(self):
        release = threading.Event()
        worker_ids = set()
        guard = threading.Lock()

        def stuck(*args, **kwargs):
            with guard:
                worker_ids.add(threading.get_ident())
            release.wait(3)
            return []

        try:
            with patch.object(module.socket, 'getaddrinfo', stuck):
                for i in range(4):
                    budget = module.MetadataBudget(0.05)
                    try:
                        with self.assertRaises(module.ResourceLimitError):
                            budget.resolve(f'host{i}.example.com', 443)
                    finally:
                        budget.close()
            self.assertLessEqual(len(worker_ids), 2)
        finally:
            release.set()


if __name__ == '__main__':
    unittest.main()
