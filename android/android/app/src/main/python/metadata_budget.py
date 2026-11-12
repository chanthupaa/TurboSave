"""Limits metadata work; Android DownloadManager transfers are not capped here."""
import concurrent.futures
import copy
import gzip
import io
import socket
import threading
import time
import urllib.response
import zlib

MAX_RESPONSE_BYTES = 4 * 1024 * 1024
MAX_TOTAL_BYTES = 16 * 1024 * 1024
READ_CHUNK = 65536
_DNS_POOL = concurrent.futures.ThreadPoolExecutor(max_workers=2, thread_name_prefix='turbosave-dns')
_DNS_SLOTS = threading.BoundedSemaphore(2)


class ResourceLimitError(ValueError):
    pass


class MetadataBudget:
    def __init__(self, seconds=65, clock=None):
        self.clock = clock or time.monotonic
        self.deadline = self.clock() + min(65, max(0, seconds))
        self.failure = None
        self.total = 0
        self.requests = 0
        self.lookups = 0
        self.addresses = {}
        self.sockets = set()
        self.lock = threading.RLock()
        self.timer = None

    def fail(self, message):
        with self.lock:
            self.failure = self.failure or message
        self._close_sockets()
        raise ResourceLimitError(self.failure)

    def check(self):
        if self.failure:
            raise ResourceLimitError(self.failure)
        if self.clock() >= self.deadline:
            self.fail('This source took too long to check. Try another link.')

    def remaining(self):
        self.check()
        return max(0.001, self.deadline - self.clock())

    def request(self):
        with self.lock:
            self.check()
            self.requests += 1
            if self.requests > 80:
                self.fail('This source made too many metadata requests. Try another link.')

    def consume(self, size):
        with self.lock:
            self.total += size
            if self.total > MAX_TOTAL_BYTES:
                self.fail('This source metadata is too large. Try another link.')

    def resolve(self, host, port, **kwargs):
        self.check()
        key = (host, port)
        with self.lock:
            if key in self.addresses:
                return self.addresses[key]
            self.lookups += 1
            if self.lookups > 64:
                self.fail('This source requires too many network lookups. Try another link.')
        if not _DNS_SLOTS.acquire(blocking=False):
            self.fail('Network lookup is busy. Try again shortly.')
        try:
            def lookup():
                self.check()
                return socket.getaddrinfo(host, port, **kwargs)
            future = _DNS_POOL.submit(lookup)
        except Exception:
            _DNS_SLOTS.release()
            raise
        future.add_done_callback(lambda _: _DNS_SLOTS.release())
        try:
            records = future.result(timeout=self.remaining())
        except concurrent.futures.TimeoutError:
            # Keep the slot until queued/running OS work actually exits.
            self.fail('This source took too long to check. Try another link.')
        self.check()
        if len(records) > 64:
            self.fail('This source returned too many network addresses. Try another link.')
        with self.lock:
            self.addresses[key] = records
        return records

    def track(self, connection):
        with self.lock:
            try:
                self.check()
            except ResourceLimitError:
                connection.close()
                raise
            self.sockets.add(connection)
            if self.timer is None:
                self.timer = threading.Timer(self.remaining(), self._expire)
                self.timer.daemon = True
                self.timer.start()
        return connection

    def _expire(self):
        with self.lock:
            self.failure = self.failure or 'This source took too long to check. Try another link.'
        self._close_sockets()

    def _close_sockets(self):
        with self.lock:
            connections = list(self.sockets)
            self.sockets.clear()
        for connection in connections:
            try:
                connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                connection.close()
            except OSError:
                pass

    def close(self):
        if self.timer is not None:
            self.timer.cancel()
        self._close_sockets()


class LimitedReader(io.BufferedIOBase):
    def __init__(self, source, budget, *, count_total=True, owner=None):
        self.source = source
        self.budget = budget
        self.count_total = count_total
        self.owner = owner
        self.used = 0

    def readable(self):
        return True

    def read(self, size=-1):
        if self.closed:
            return b''
        self.budget.check()
        target = MAX_RESPONSE_BYTES - self.used + 1
        if size is not None and size >= 0:
            target = min(target, size)
        data = bytearray()
        try:
            while len(data) < target:
                self.budget.check()
                reader = getattr(self.source, 'read1', self.source.read)
                chunk = reader(min(READ_CHUNK, target - len(data)))
                self.budget.check()
                if not chunk:
                    self.close()
                    break
                self.used += len(chunk)
                if self.used > MAX_RESPONSE_BYTES:
                    self.budget.fail('This source metadata is too large. Try another link.')
                if self.count_total:
                    self.budget.consume(len(chunk))
                data.extend(chunk)
            return bytes(data)
        except Exception:
            self.close()
            raise

    read1 = read

    def close(self):
        if self.closed:
            return
        try:
            self.source.close()
        finally:
            try:
                if self.owner is not None:
                    self.owner.close()
            finally:
                super().close()


class DeflateReader(io.BufferedIOBase):
    def __init__(self, source):
        self.source = source
        self.pending = source.read(READ_CHUNK)
        header = self.pending[:2]
        wrapped = len(header) == 2 and header[0] & 15 == 8 and int.from_bytes(header, 'big') % 31 == 0
        self.decoder = zlib.decompressobj(zlib.MAX_WBITS if wrapped else -zlib.MAX_WBITS)

    def read(self, size=READ_CHUNK):
        size = min(READ_CHUNK, size if size is not None and size >= 0 else READ_CHUNK)
        if size == 0:
            return b''
        while True:
            data = self.decoder.decompress(self.pending, size)
            self.pending = self.decoder.unconsumed_tail
            if data or self.decoder.eof:
                return data
            if not self.pending:
                self.pending = self.source.read(READ_CHUNK)
                if not self.pending:
                    raise zlib.error('Incomplete deflate response')

    read1 = read

    def close(self):
        try:
            self.source.close()
        finally:
            super().close()


def limit_metadata_response(response, budget, *, head=False):
    budget.check()
    header_bytes = 0
    for key, value in response.headers.items():
        header_bytes += len(key) + len(value) + 4
        if header_bytes > 65536:
            response.close()
            budget.fail('This source metadata headers are too large. Try another link.')
    if head:
        return response
    encoding = response.headers.get('Content-Encoding', '').strip().lower()
    if encoding not in ('', 'identity', 'gzip', 'x-gzip', 'deflate'):
        response.close()
        budget.fail('This source returned unsupported compressed metadata. Try another link.')
    headers = copy.copy(response.headers)
    if encoding in ('gzip', 'x-gzip', 'deflate'):
        wire = LimitedReader(response, budget, count_total=False)
        decoded = DeflateReader(wire) if encoding == 'deflate' else gzip.GzipFile(fileobj=wire)
        reader = LimitedReader(decoded, budget, owner=wire)
        del headers['Content-Encoding']
        if 'Content-Length' in headers:
            del headers['Content-Length']
    else:
        reader = LimitedReader(response, budget)
    wrapped = urllib.response.addinfourl(reader, headers, response.url, response.code)
    wrapped.msg = getattr(response, 'msg', None)
    return wrapped
