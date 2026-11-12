import importlib.util
import json
import pathlib
import re
import socket
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'android/app/src/main/python/media_extractor.py'
spec=importlib.util.spec_from_file_location('mobile_extractor',SOURCE)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
public=lambda *a,**k:[(socket.AF_INET,socket.SOCK_STREAM,6,'',('8.8.8.8',443))]
private=lambda *a,**k:[(socket.AF_INET,socket.SOCK_STREAM,6,'',('127.0.0.1',443))]

class ExtractorPolicyTest(unittest.TestCase):
    def test_restricted_sources_fail_before_dns(self):
        def no_dns(*a,**k):self.fail('Blocked source performed DNS lookup')
        for host in ('music.youtube.com','youtu.be','www.pornhub.com','www.eporner.com'):
            with self.assertRaises(module.PolicyError):module.validate_url('https://'+host+'/',True,no_dns)

    def test_open_flavor_allows_domains_but_retains_public_network_rules(self):
        self.assertEqual(module.validate_url('https://youtube.com/watch',False,public)[0].hostname,'youtube.com')
        for flavor in (True,False):
            for value in ('http://example.com/a','https://user:pass@example.com/a','https://example.com:8443/a','https://localhost/a','https://127.0.0.1/a'):
                with self.assertRaises(module.PolicyError):module.validate_url(value,flavor,public)
            with self.assertRaises(module.PolicyError):module.validate_url('https://example.com/a',flavor,private)

    def test_all_policy_lists_match(self):
        dart=(ROOT/'lib/services/media_policy.dart').read_text()
        hosts=set(re.findall(r"'([a-z0-9][a-z0-9.-]+\.[a-z]{2,})'",dart[dart.index('static bool _blocked'):]))
        native=set(json.loads((ROOT/'android/app/src/main/assets/restricted_hosts.json').read_text()))
        self.assertEqual(hosts,module.HOSTS);self.assertEqual(hosts,native)

    def test_only_complete_formats_are_returned_and_duplicates_are_compacted(self):
        url='https://cdn.example.com/file.mp4'
        base={'format_id':'a','ext':'mp4','url':url,'protocol':'https','vcodec':'avc1','acodec':'aac','height':720,'filesize':1000}
        info={'formats':[base,{**base,'format_id':'b','filesize':2000},{**base,'format_id':'silent','acodec':'none'},{**base,'format_id':'drm','has_drm':True},{**base,'format_id':'hls','protocol':'m3u8_native'},{**base,'format_id':'audio','vcodec':'none','ext':'m4a','height':None,'abr':128}]}
        result=module.normalized_formats(info,False,lambda value,flag:module.validate_url(value,flag,public))
        self.assertEqual([f['id'] for f in result],['b','audio']);self.assertEqual(result[0]['size'],2000)

    def test_live_drm_playlist_and_reported_adult_metadata_are_restricted(self):
        for info in ({'is_live':True},{'has_drm':True},{'_type':'playlist'},{'age_limit':18},{'availability':'private'}):
            with self.assertRaises(module.PolicyError):module.normalized_formats(info,True)
        self.assertEqual(module.normalized_formats({'age_limit':18,'formats':[]},False),[])

    def test_remote_headers_do_not_add_credentials_or_newlines(self):
        headers=module.clean_headers({'User-Agent':'TurboSave','Cookie':'private','Authorization':'private','Referer':'https://example.com/','accept':'a\r\nb'})
        self.assertEqual(headers,{'User-Agent':'TurboSave','Referer':'https://example.com/'})

    def test_trusted_extractor_cookie_is_forwarded_only_in_memory(self):
        class Jar:
            def get_cookie_header(self,url):return 'challenge=temporary'
        result=module.normalized_formats(
            {'formats':[{'format_id':'a','ext':'mp4','url':'https://cdn.example.com/file.mp4','protocol':'https','vcodec':'avc1','acodec':'aac'}]},
            False,lambda value,flag:module.validate_url(value,flag,public),cookiejar=Jar())
        self.assertEqual(result[0]['sessionCookie'],'challenge=temporary')
        self.assertNotIn('Cookie',result[0]['headers'])
        self.assertEqual(module.session_headers(Jar(),'https://cdn.example.com/file.mp4'),{'Cookie':'challenge=temporary'})

    def test_tiktok_and_instagram_slideshows_return_at_most_twenty_images(self):
        for source in ('https://www.tiktok.com/@creator/photo/1','https://www.instagram.com/p/example/'):
            info={'_type':'multi_video','entries':[
                {'id':str(i),'url':f'https://cdn.example.com/image-{i}.jpg','ext':'jpg','width':1080,'height':1920}
                for i in range(25)
            ]}
            result=module.normalized_images(
                info,source,False,
                lambda value,flag:module.validate_url(value,flag,public))
            self.assertEqual(len(result),20)
            self.assertTrue(all(item['imageOnly'] for item in result))
            self.assertEqual(result[0]['imageIndex'],1)
            self.assertEqual(result[-1]['imageIndex'],20)

    def test_image_collection_rejects_other_sites_and_unsafe_entries(self):
        info={'_type':'playlist','entries':[
            {'url':'https://cdn.example.com/one.webp','ext':'webp'},
            {'url':'https://127.0.0.1/private.png','ext':'png'},
            {'url':'https://cdn.example.com/not-media.mp4','ext':'mp4'},
        ]}
        validator=lambda value,flag:module.validate_url(value,flag,public if '127.0.0.1' not in value else private)
        with self.assertRaises(module.PolicyError):
            module.normalized_images(info,'https://example.com/list',False,validator)
        result=module.normalized_images(
            info,'https://www.instagram.com/p/example/',False,validator)
        self.assertEqual([item['ext'] for item in result],['webp'])

if __name__=='__main__':unittest.main()
