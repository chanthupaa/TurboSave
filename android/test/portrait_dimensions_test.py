import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'android/app/src/main/python/media_extractor.py'
spec = importlib.util.spec_from_file_location('mobile_extractor_dimensions', SOURCE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PortraitDimensionsTest(unittest.TestCase):
    def test_width_and_height_are_preserved(self):
        formats = module.normalized_formats(
            {
                'formats': [{
                    'format_id': 'portrait',
                    'url': 'https://cdn.example.com/video.mp4',
                    'ext': 'mp4',
                    'protocol': 'https',
                    'vcodec': 'avc1',
                    'acodec': 'aac',
                    'width': 720,
                    'height': 1280,
                }],
            },
            False,
            lambda value, restricted: None,
        )
        self.assertEqual((formats[0]['width'], formats[0]['height']), (720, 1280))


if __name__ == '__main__':
    unittest.main()
