"""Unknown progressive files stay distinct from explicitly absent tracks."""
import importlib.util
import pathlib
import socket
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'android/app/src/main/python/media_extractor.py'
spec = importlib.util.spec_from_file_location('unknown_codec_extractor', SOURCE)
extractor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extractor)


class UnknownCodecsTest(unittest.TestCase):
    def formats(self, **changes):
        raw = {'ext': 'mp4', 'url': 'https://cdn.example.com/clip.mp4', 'vcodec': None}
        raw.update(changes)
        return extractor.normalized_formats({'formats': [raw]}, False, lambda *args: None)

    def test_plain_video_files_with_missing_codecs_are_marked_unverified(self):
        for ext in ('mp4', 'webm', 'mov', 'mkv'):
            with self.subTest(ext=ext):
                formats = self.formats(ext=ext, url=f'https://cdn.example.com/clip.{ext}?signed=value')
                self.assertEqual(len(formats), 1)
                self.assertFalse(formats[0]['audioOnly'])
                self.assertTrue(formats[0]['audioUnknown'])

    def test_absent_and_null_codecs_have_the_same_meaning(self):
        for fields in ({}, {'vcodec': None}, {'acodec': None}, {'vcodec': None, 'acodec': None}):
            with self.subTest(fields=fields):
                raw = {'ext': 'mp4', 'url': 'https://cdn.example.com/clip.mp4', **fields}
                formats = extractor.normalized_formats({'formats': [raw]}, False, lambda *args: None)
                self.assertEqual(len(formats), 1)
                self.assertTrue(formats[0]['audioUnknown'])

    def test_explicitly_silent_video_stays_rejected(self):
        for video_codec in (None, 'avc1'):
            with self.subTest(video_codec=video_codec):
                self.assertEqual(self.formats(vcodec=video_codec, acodec='none'), [])

    def test_partially_reported_video_track_is_not_assumed_to_include_audio(self):
        self.assertEqual(self.formats(vcodec='avc1'), [])

    def test_unknown_audio_in_a_video_container_is_not_assumed_complete(self):
        self.assertEqual(self.formats(vcodec='none'), [])

    def test_segmented_or_adaptive_unknown_formats_stay_rejected(self):
        for fields in (
            {'protocol': 'm3u8_native'}, {'protocol': 'http_dash_segments'},
            {'manifest_url': 'https://cdn.example.com/playlist.mpd'},
            {'fragments': [{'url': 'https://cdn.example.com/segment.m4s'}]},
            {'fragment_base_url': 'https://cdn.example.com/segments/'},
            {'container': 'mp4_dash'},
        ):
            with self.subTest(fields=fields):
                self.assertEqual(self.formats(**fields), [])

    def test_unknown_formats_need_a_matching_supported_file_extension(self):
        for fields in (
            {'url': 'https://cdn.example.com/playlist.m3u8'},
            {'url': 'https://cdn.example.com/segment.m4s'},
            {'url': 'https://cdn.example.com/download?id=mp4'},
            {'url': 'https://cdn.example.com/clip.webm'},
            {'ext': 'exe'}, {'ext': 'm4a'},
        ):
            with self.subTest(fields=fields):
                self.assertEqual(self.formats(**fields), [])

    def test_malformed_codec_values_are_not_unknown(self):
        for value in ('', [], {}, 0, False):
            with self.subTest(value=value):
                self.assertEqual(self.formats(acodec=value), [])

    def test_known_complete_video_and_audio_keep_their_kind(self):
        video = self.formats(vcodec='avc1', acodec='aac')[0]
        audio = self.formats(vcodec='none', acodec='aac', ext='m4a')[0]
        self.assertFalse(video['audioOnly'])
        self.assertFalse(video.get('audioUnknown', False))
        self.assertTrue(audio['audioOnly'])
        self.assertFalse(audio.get('audioUnknown', False))

    def test_unknown_files_still_pass_through_url_and_drm_policy(self):
        public = lambda *args, **kwargs: [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('8.8.8.8', 443))]
        private = lambda *args, **kwargs: [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('127.0.0.1', 443))]
        for url, resolver in (
            ('https://user:pass@example.com/clip.mp4', public),
            ('http://example.com/clip.mp4', public),
            ('https://example.com/clip.mp4', private),
            ('https://youtube.com/clip.mp4', public),
        ):
            with self.subTest(url=url):
                info = {'formats': [{'url': url, 'ext': 'mp4'}]}
                self.assertEqual(extractor.normalized_formats(
                    info, True, lambda value, flag: extractor.validate_url(value, flag, resolver)), [])
        self.assertEqual(self.formats(has_drm=True), [])

    def test_uncertain_file_does_not_displace_a_known_complete_format(self):
        unknown = {'format_id': 'unknown', 'ext': 'mp4', 'url': 'https://cdn.example.com/clip.mp4', 'filesize': 2000}
        known = {**unknown, 'format_id': 'known', 'filesize': 1000, 'vcodec': 'avc1', 'acodec': 'aac'}
        for formats in ([unknown, known], [known, unknown]):
            with self.subTest(order=[item['format_id'] for item in formats]):
                result = extractor.normalized_formats({'formats': formats}, False, lambda *args: None)
                self.assertEqual([item['id'] for item in result], ['known'])

    def test_cancellation_is_checked_while_validating_unknown_files(self):
        checked = False
        def validator(*args):
            nonlocal checked
            checked = True
        def check():
            if checked:
                raise TimeoutError('Budget expired')
        with self.assertRaises(TimeoutError):
            extractor.normalized_formats({'formats': [{
                'url': 'https://cdn.example.com/clip.mp4', 'ext': 'mp4',
            }]}, False, validator, check)


if __name__ == '__main__':
    unittest.main()
