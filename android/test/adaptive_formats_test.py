import importlib.util
import pathlib
import unittest


SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'android/app/src/main/python/media_extractor.py'
spec = importlib.util.spec_from_file_location('adaptive_extractor', SOURCE)
extractor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extractor)


class AdaptiveFormatsTest(unittest.TestCase):
    def setUp(self):
        self.video = {'format_id': 'v720', 'url': 'https://cdn.example.com/video.mp4',
                      'ext': 'mp4', 'protocol': 'https', 'vcodec': 'avc1.64001f',
                      'acodec': 'none', 'height': 720, 'filesize': 1000,
                      'http_headers': {'Referer': 'https://example.com/video'}}
        self.audio = {'format_id': 'a128', 'url': 'https://audio.example.com/audio.m4a',
                      'ext': 'm4a', 'protocol': 'https', 'vcodec': 'none',
                      'acodec': 'mp4a.40.2', 'abr': 128, 'filesize': 200,
                      'http_headers': {'User-Agent': 'Audio client'}}

    def formats(self, *items):
        return extractor.normalized_formats({'formats': list(items)}, False, lambda *args: None)

    def test_pairs_tracks_and_keeps_complete_and_audio_formats(self):
        complete = {**self.video, 'format_id': 'complete', 'acodec': 'mp4a.40.2'}
        result = self.formats(self.video, self.audio, complete)
        self.assertEqual([item['id'] for item in result], ['complete', 'v720+a128', 'a128'])
        paired = result[1]
        self.assertEqual((paired['url'], paired['audioUrl']), (self.video['url'], self.audio['url']))
        self.assertEqual((paired['headers'], paired['audioHeaders']),
                         ({'Referer': 'https://example.com/video'}, {'User-Agent': 'Audio client'}))
        self.assertEqual(paired['size'], 1200)
        self.assertTrue(paired['requiresMerge'])
        self.assertFalse(paired['audioUnknown'])

    def test_silent_track_alone_or_incompatible_audio_is_not_offered(self):
        self.assertEqual(self.formats(self.video), [])
        for audio in ({**self.audio, 'acodec': 'opus'},
                      {**self.audio, 'ext': 'webm'},
                      {**self.audio, 'url': 'http://audio.example.com/audio.m4a'},
                      {**self.audio, 'url': 'https://audio.example.com/playlist.m3u8'}):
            with self.subTest(audio=audio):
                self.assertFalse(any(item.get('requiresMerge') for item in self.formats(self.video, audio)))

    def test_manifest_fragments_and_drm_never_pair(self):
        for field in ({'has_drm': True}, {'protocol': 'm3u8_native'},
                      {'fragments': [{'url': 'segment.m4s'}]},
                      {'manifest_url': 'https://cdn.example.com/list.mpd'},
                      {'container': 'mp4_dash'}):
            with self.subTest(field=field):
                self.assertFalse(any(item.get('requiresMerge') for item in self.formats({**self.video, **field}, self.audio)))
                self.assertFalse(any(item.get('requiresMerge') for item in self.formats(self.video, {**self.audio, **field})))


if __name__ == '__main__':
    unittest.main()
