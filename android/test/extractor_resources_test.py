"""Controlled transport tests: no external service or extra Python package."""
import gzip
import importlib.util
import io
import json
import pathlib
import socket
import sys
import types
import unittest
import urllib.request
import urllib.response
from email.message import Message
from unittest.mock import patch

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'android/app/src/main/python'
spec = importlib.util.spec_from_file_location('resource_extractor', SOURCE / 'media_extractor.py')
extractor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extractor)


class ExtractorResourceTest(unittest.TestCase):
    def run_extraction(self, body=b'normal metadata', encoding='', delay=0,
                       requests=1, dns_delay=0, formats=1, request_url=None):
        now = [0.0]
        reads = []
        headers_sent = []
        replies = []

        class Body(io.BytesIO):
            def read(self, size=-1):
                reads.append(size)
                now[0] += delay
                return super().read(size)

            read1 = read

        class Fixture(urllib.request.BaseHandler):
            handler_order = 0

            def https_open(self, request):
                headers_sent.append(dict(request.header_items()))
                headers = Message()
                headers['Content-Type'] = 'text/html'
                if encoding:
                    headers['Content-Encoding'] = encoding
                stream = Body(body)
                replies.append(stream)
                response = urllib.response.addinfourl(stream, headers, request.full_url, 200)
                response.msg = 'OK'
                return response

        class LegacyCompression(urllib.request.BaseHandler):
            handler_order = 500

            def https_response(self, request, response):
                if response.headers.get('Content-Encoding') == 'gzip':
                    # Mirrors the installed yt-dlp handler's eager decompression.
                    decoded = gzip.decompress(response.read())
                    old = response
                    response = urllib.response.addinfourl(io.BytesIO(decoded), old.headers, old.url, old.code)
                    response.msg = 'OK'
                return response

        class RH:
            def _create_instance(self, *args, **kwargs):
                opener = urllib.request.OpenerDirector()
                opener.add_handler(Fixture())
                opener.add_handler(LegacyCompression())
                return opener

            def close(self):
                pass

        class YDL:
            def __init__(self, params):
                self._request_director = types.SimpleNamespace(handlers={'urllib': RH()})

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def extract_info(self, value, download=False):
                handler = self._request_director.handlers['urllib']
                opener = handler._create_instance({}, None)
                for _ in range(requests):
                    with opener.open(request_url or value, timeout=12) as response:
                        response.read()
                return {'title': 'Fixture', 'webpage_url': value, 'formats': [
                    {'format_id': str(i), 'ext': 'mp4', 'protocol': 'https',
                     'url': f'https://cdn{i}.example.com/video.mp4',
                     'vcodec': 'avc1', 'acodec': 'aac', 'height': 360}
                    for i in range(formats)
                ]}

        def dns(*args, **kwargs):
            now[0] += dns_delay
            return [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('8.8.8.8', 443))]

        modules = {
            'certifi': types.SimpleNamespace(where=lambda: None),
            'yt_dlp': types.SimpleNamespace(YoutubeDL=YDL),
            'yt_dlp.networking._urllib': types.SimpleNamespace(UrllibRH=RH),
        }
        with patch.dict(sys.modules, modules), patch.object(extractor.socket, 'getaddrinfo', dns), \
                patch.object(extractor.time, 'monotonic', lambda: now[0]), \
                patch.object(sys, 'path', [str(SOURCE), *sys.path]):
            result = json.loads(extractor.extract('https://example.com/page', False))
        return result, reads, headers_sent, replies

    def test_slow_continuous_body_cannot_outlive_the_operation(self):
        result, _, _, replies = self.run_extraction(delay=70)
        self.assertIn('took too long', result.get('error', ''))
        self.assertTrue(all(reply.closed for reply in replies))

    def test_large_metadata_is_rejected_without_unbounded_reads(self):
        result, reads, _, replies = self.run_extraction(body=b'x' * (4 * 1024 * 1024 + 1))
        self.assertIn('too large', result.get('error', ''))
        self.assertTrue(reads)
        self.assertTrue(all(0 < size <= 65536 for size in reads))
        self.assertTrue(all(reply.closed for reply in replies))

    def test_compressed_expansion_cannot_bypass_the_decoded_limit(self):
        result, _, _, _ = self.run_extraction(
            body=gzip.compress(b'x' * (4 * 1024 * 1024 + 1)), encoding='gzip')
        self.assertIn('too large', result.get('error', ''))

    def test_metadata_total_is_bounded_across_multiple_requests(self):
        result, _, _, _ = self.run_extraction(body=b'x' * (4 * 1024 * 1024), requests=5)
        self.assertIn('too large', result.get('error', ''))

    def test_format_validation_remains_inside_the_deadline(self):
        result, _, _, _ = self.run_extraction(dns_delay=20, formats=8)
        self.assertIn('took too long', result.get('error', ''))

    def test_normal_metadata_and_gzip_still_work(self):
        for encoding in ('', 'gzip'):
            with self.subTest(encoding=encoding):
                body = gzip.compress(b'normal metadata') if encoding else b'normal metadata'
                result, _, _, replies = self.run_extraction(body=body, encoding=encoding)
                self.assertNotIn('error', result)
                self.assertEqual(len(result['formats']), 1)
                self.assertTrue(all(reply.closed for reply in replies))

    def test_a_valid_operation_succeeds_after_a_timeout(self):
        failed, _, _, _ = self.run_extraction(delay=70)
        self.assertIn('error', failed)
        recovered, _, _, _ = self.run_extraction()
        self.assertNotIn('error', recovered)

    def test_non_https_subrequests_cannot_bypass_the_metadata_gate(self):
        for url in ('data:text/html,ignored', 'ftp://example.com/ignored', 'http://example.com/ignored'):
            with self.subTest(url=url):
                result, reads, _, _ = self.run_extraction(request_url=url)
                self.assertIn('HTTPS', result.get('error', ''))
                self.assertEqual(reads, [])


if __name__ == '__main__':
    unittest.main()
