"""Audit only: mirrors yt-dlp's HTML5-video metadata for a known complete MP4."""
import importlib.util
import pathlib
import unittest

root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('second_audit_extractor', root / 'android/app/src/main/python/media_extractor.py')
extractor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extractor)

class GenericVideoAudit(unittest.TestCase):
    def test_html5_video_without_codec_metadata_is_not_discarded(self):
        # This shape was obtained from the installed GenericIE HTML5 parser.
        info = {'formats': [{
            'ext': 'mp4', 'url': 'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
            'vcodec': None, 'http_headers': {'Referer': 'https://example.com/post'},
        }]}
        self.assertEqual(len(extractor.normalized_formats(info, False, lambda *args: None)), 1)

if __name__ == '__main__':
    unittest.main()
