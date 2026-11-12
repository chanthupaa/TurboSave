"""Local metadata extraction with HTTPS-only, DNS-pinned requests."""
import http.client
import ipaddress
import json
import pathlib
import re
import socket
import ssl
import time
import types
import urllib.parse
import urllib.request

HOSTS = frozenset(json.loads(pathlib.Path(__file__).with_name('restricted_hosts.json').read_text()))
EXTENSIONS = frozenset(('mp4','webm','mov','mkv','mp3','m4a','ogg','oga','wav','flac'))
IMAGE_EXTENSIONS = frozenset(('jpg','jpeg','png','webp'))
ADULT_NAME = re.compile(r'(^|[.\-])(pornhub|porno|porn|xxx|xvideos|xnxx|redtube|erotic)([.\-]|$)')

class PolicyError(ValueError):
    pass

def validate_url(value, restricted=True, resolver=None):
    if not isinstance(value,str) or len(value)>8192: raise PolicyError('Use one public HTTPS media link.')
    try:
        uri=urllib.parse.urlsplit(value.strip());host=(uri.hostname or '').lower().rstrip('.')
        if uri.scheme!='https' or not host or uri.username is not None or uri.password is not None or uri.port not in (None,443):raise ValueError()
    except (ValueError,TypeError):raise PolicyError('Use a public HTTPS link without login details.') from None
    if host=='localhost' or host.endswith(('.localhost','.local','.internal','.onion')) or ':' in host or re.fullmatch(r'[0-9.]+',host):raise PolicyError('Private network destinations are not supported.')
    if restricted and (any(host==domain or host.endswith('.'+domain) for domain in HOSTS) or ADULT_NAME.search(host)):raise PolicyError('YouTube and identified adult sites are excluded in this edition.')
    records=(resolver or socket.getaddrinfo)(host,443,type=socket.SOCK_STREAM)
    if not records or any(not ipaddress.ip_address(item[4][0]).is_global for item in records):raise PolicyError('Private network destinations are not supported.')
    return uri,records

def clean_headers(value):
    if not isinstance(value,dict):return {}
    return {str(k):v for k,v in value.items() if str(k).lower() in {'user-agent','referer','accept'} and isinstance(v,str) and len(v)<1000 and not re.search(r'[\r\n\x00]',v)}

def session_headers(cookiejar,url):
    if cookiejar is None or not hasattr(cookiejar,'get_cookie_header'):return {}
    value=cookiejar.get_cookie_header(url)
    if not isinstance(value,str) or not value or len(value)>4096 or re.search(r'[\r\n\x00]',value):return {}
    return {'Cookie':value}

def normalized_formats(info,restricted=True,validator=validate_url,check=None,cookiejar=None):
    if check:check()
    if info.get('_type') in ('playlist','multi_video') or info.get('is_live') or info.get('has_drm'):raise PolicyError('Use one non-live, unprotected public video or audio post.')
    if restricted and float(info.get('age_limit') or 0)>=18:raise PolicyError('Reported adult media is excluded in this edition.')
    if info.get('availability') in ('private','premium_only','subscriber_only','needs_auth'):raise PolicyError('This source needs sign-in or authorization. Public media only.')
    result={};silent_videos=[];pairable_audio=[]
    for raw in (info.get('formats') or [info])[:500]:
        if check:check()
        ext=str(raw.get('ext','')).lower();protocol=str(raw.get('protocol','https'))
        if ext not in EXTENSIONS or protocol not in ('https','http') or raw.get('has_drm'):continue
        if any(raw.get(key) for key in ('manifest_url','fragments','fragment_base_url','requested_formats')) or str(raw.get('container','')).endswith('_dash'):continue
        vcodec=raw.get('vcodec');acodec=raw.get('acodec')
        if any(codec is not None and (not isinstance(codec,str) or not codec) for codec in (vcodec,acodec)):continue
        silent=acodec=='none'
        video=vcodec not in (None,'none');audio_unknown=acodec is None
        url=raw.get('url')
        if silent and (not video or ext!='mp4'):continue
        if audio_unknown:
            # shortcut: unknown standalone files may have sound; a track parser is needed to prove it.
            if vcodec is not None or ext not in ('mp4','webm','mov','mkv'):continue
            if not isinstance(url,str):continue
            try:
                if pathlib.PurePosixPath(urllib.parse.urlsplit(url).path).suffix.lower()!='.'+ext:continue
            except ValueError:continue
            video=True
        try:validator(url,restricted)
        except (ValueError,OSError):
            if check:check()
            continue
        if check:check()
        headers=clean_headers({**(info.get('http_headers') or {}),**(raw.get('http_headers') or {})})
        trusted_session=session_headers(cookiejar,url).get('Cookie')
        width=raw.get('width') if video and isinstance(raw.get('width'),(int,float)) else None
        height=raw.get('height') if video and isinstance(raw.get('height'),(int,float)) else None
        abr=round(raw['abr']) if isinstance(raw.get('abr'),(int,float)) and raw['abr']>0 else None
        size=raw.get('filesize') or raw.get('filesize_approx')
        if not isinstance(size,(int,float)) or size<=0:size=None
        key=(video,width,height,ext,abr if not video else None,raw.get('language'))
        candidate={'id':str(raw.get('format_id') or len(result))[:100],'url':url,'ext':ext,'width':width,'height':height,'size':int(size) if size else None,'audioOnly':not video,'audioUnknown':audio_unknown,'abr':abr,'language':raw.get('language'),'headers':headers,'sessionCookie':trusted_session}
        # A silent track is only offered when a separate, compatible audio file exists.
        parsed=urllib.parse.urlsplit(url)
        suffix=pathlib.PurePosixPath(parsed.path.lower()).suffix
        direct_file=parsed.scheme=='https' and suffix in ('','.mp4','.m4a')
        if silent:
            if direct_file and suffix in ('','.mp4') and vcodec.lower().startswith(('avc1','avc3')):silent_videos.append(candidate)
            continue
        if not video and ext in ('m4a','mp4') and direct_file and acodec and acodec.lower().startswith(('mp4a','aac')):
            pairable_audio.append(candidate)
        previous=result.get(key)
        if previous is None or (previous['audioUnknown'] and not audio_unknown) or (previous['audioUnknown']==audio_unknown and (candidate['size'] or 0)>(previous['size'] or 0)):result[key]=candidate
    composites=[]
    for video in silent_videos:
        if check:check()
        audio=max((item for item in pairable_audio if item['url']!=video['url']),key=lambda item:(item['language']==video['language'],item['abr'] or 0),default=None)
        if audio is None:continue
        combined={**video,'id':video['id']+'+'+audio['id'],'audioUrl':audio['url'],'audioExt':audio['ext'],'audioHeaders':audio['headers'],'audioSessionCookie':audio['sessionCookie'],'requiresMerge':True,'audioUnknown':False}
        combined['size']=video['size']+audio['size'] if video['size'] is not None and audio['size'] is not None else None
        composites.append(combined)
    if check:check()
    sort_key=lambda f:(f['audioOnly'],-(f['height'] or f['abr'] or 0),f['ext'])
    complete=sorted(result.values(),key=sort_key)[:80]
    return sorted(complete+composites[:80-len(complete)],key=sort_key)

def normalized_images(info,source_url,restricted=True,validator=validate_url,check=None,cookiejar=None):
    if check:check()
    source=urllib.parse.urlsplit(source_url);host=(source.hostname or '').lower().rstrip('.');path=source.path.rstrip('/')+'/'
    supported=(host=='tiktok.com' or host.endswith('.tiktok.com')) and '/photo/' in path
    supported=supported or ((host=='instagram.com' or host.endswith('.instagram.com')) and '/p/' in path)
    if not supported:raise PolicyError('Use one public TikTok photo post or Instagram carousel link.')
    if info.get('is_live') or info.get('has_drm'):raise PolicyError('Use one non-live, unprotected public media post.')
    if restricted and float(info.get('age_limit') or 0)>=18:raise PolicyError('Reported adult media is excluded in this edition.')
    if info.get('availability') in ('private','premium_only','subscriber_only','needs_auth'):raise PolicyError('This source needs sign-in or authorization. Public media only.')
    entries=info.get('entries')
    if not isinstance(entries,list):return []
    result=[];seen=set()
    for entry in entries:
        if check:check()
        if not isinstance(entry,dict):continue
        candidates=[entry]+[item for item in (entry.get('formats') or []) if isinstance(item,dict)]
        chosen=None
        for raw in candidates:
            url=raw.get('url')
            if not isinstance(url,str) or url in seen:continue
            ext=str(raw.get('ext') or pathlib.PurePosixPath(urllib.parse.urlsplit(url).path).suffix.lstrip('.')).lower()
            if ext not in IMAGE_EXTENSIONS or str(raw.get('protocol','https')) not in ('https','http'):continue
            try:validator(url,restricted)
            except (ValueError,OSError):continue
            chosen=(raw,url,ext);break
        if chosen is None:continue
        raw,url,ext=chosen;seen.add(url)
        headers=clean_headers({**(info.get('http_headers') or {}),**(entry.get('http_headers') or {}),**(raw.get('http_headers') or {})})
        trusted_session=session_headers(cookiejar,url).get('Cookie')
        size=raw.get('filesize') or raw.get('filesize_approx') or entry.get('filesize') or entry.get('filesize_approx')
        if not isinstance(size,(int,float)) or size<=0:size=None
        width=raw.get('width') if isinstance(raw.get('width'),(int,float)) else entry.get('width')
        height=raw.get('height') if isinstance(raw.get('height'),(int,float)) else entry.get('height')
        result.append({'id':'image-'+str(len(result)+1),'url':url,'ext':ext,'width':int(width) if isinstance(width,(int,float)) else None,'height':int(height) if isinstance(height,(int,float)) else None,'size':int(size) if size else None,'audioOnly':False,'imageOnly':True,'imageIndex':len(result)+1,'headers':headers,'sessionCookie':trusted_session})
        if len(result)>=20:break
    return result

class QuietLogger:
    def debug(self,*args):pass
    def warning(self,*args):pass
    def error(self,*args):pass

def extract(value,restricted=True,timeout_seconds=65):
    started=time.monotonic()
    from metadata_budget import MetadataBudget, limit_metadata_response
    budget=MetadataBudget(max(0,timeout_seconds-(time.monotonic()-started)),clock=time.monotonic)
    try:
        def checked_url(value,flag=restricted):
            budget.check()
            result=validate_url(value,flag,resolver=budget.resolve)
            budget.check()
            return result
        checked_url(value)
        import certifi
        from yt_dlp import YoutubeDL
        from yt_dlp.networking._urllib import UrllibRH
        context=ssl.create_default_context(cafile=certifi.where())

        class Gate(urllib.request.BaseHandler):
            handler_order=50
            def default_open(self,request):
                checked_url(request.full_url)
                return None
            def https_request(self,request):
                budget.request()
                checked_url(request.full_url)
                request.remove_header('Accept-encoding')
                request.add_header('Accept-Encoding','identity')
                return request
            http_request=https_request
            def https_response(self,request,response):
                return limit_metadata_response(response,budget,head=request.get_method()=='HEAD')
            http_response=https_response

        class PinnedTLS(http.client.HTTPSConnection):
            def connect(self):
                if self._tunnel_host:raise PolicyError('External proxies are not used by this app.')
                _,records=checked_url('https://'+self.host+'/')
                last=None
                for record in sorted(records,key=lambda r:r[0]!=socket.AF_INET)[:6]:
                    budget.check()
                    raw=None;wrapped=None
                    try:
                        raw=budget.track(socket.socket(record[0],record[1],record[2]))
                        raw.settimeout(min(self.timeout or 12,budget.remaining()))
                        raw.connect(record[4])
                        wrapped=context.wrap_socket(raw,server_hostname=self.host,do_handshake_on_connect=False)
                        budget.track(wrapped)
                        wrapped.settimeout(min(self.timeout or 12,budget.remaining()))
                        wrapped.do_handshake()
                        self.sock=wrapped
                        budget.check()
                        return
                    except OSError as error:
                        last=error
                        if wrapped is not None:wrapped.close()
                        if raw is not None:raw.close()
                raise last or OSError('No public connection was available')

        class TLSHandler(urllib.request.HTTPSHandler):
            handler_order=100
            def https_open(self,request):return self.do_open(PinnedTLS,request,context=context)

        # Carousel extractors expose their images as entries. Keep expansion on,
        # then allow only the bounded TikTok/Instagram slideshow routes below.
        params={'quiet':True,'no_warnings':True,'logger':QuietLogger(),'skip_download':True,'noplaylist':False,'extract_flat':False,'cachedir':False,'socket_timeout':12,'retries':1,'extractor_retries':1,'fragment_retries':1,'proxy':'','js_runtimes':{},'allow_unplayable_formats':False,'usenetrc':False,'ignoreconfig':True,'extractor_args':{'youtube':{'player_client':['android_vr','web_embedded']}}}
        with YoutubeDL(params) as ydl:
            director=ydl._request_director
            for key in list(director.handlers):
                handler=director.handlers[key]
                if not isinstance(handler,UrllibRH):handler.close();del director.handlers[key]
                else:
                    original=handler._create_instance
                    def create_instance(self,proxies,cookiejar,legacy_ssl_support=None,_original=original):
                        opener=_original(proxies,cookiejar,legacy_ssl_support)
                        opener.add_handler(Gate());opener.add_handler(TLSHandler(context=context))
                        return opener
                    handler._create_instance=types.MethodType(create_instance,handler)
            info=ydl.extract_info(value,download=False)
            budget.check()
            if not isinstance(info,dict):raise PolicyError('This post did not return media details.')
            if info.get('webpage_url'):checked_url(info['webpage_url'])
            if info.get('_type') in ('playlist','multi_video') or isinstance(info.get('entries'),list):
                formats=normalized_images(info,value,restricted,checked_url,check=budget.check,cookiejar=getattr(ydl,'cookiejar',None))
            else:
                formats=normalized_formats(info,restricted,checked_url,check=budget.check,cookiejar=getattr(ydl,'cookiejar',None))
        budget.check()
        if not formats:raise PolicyError('No complete downloadable video, audio, or slideshow image was available. This source may need sign-in or a different format.')
        thumbnail=info.get('thumbnail') or ''
        if thumbnail:
            try:checked_url(thumbnail)
            except (ValueError,OSError):thumbnail=''
        result={'title':str(info.get('title') or 'Public media')[:220],'author':str(info.get('uploader') or info.get('channel') or '')[:160],'thumbnail':thumbnail,'duration':round(info['duration']) if isinstance(info.get('duration'),(int,float)) else None,'formats':formats}
        encoded=json.dumps(result,ensure_ascii=False)
        budget.check()
        return encoded
    except PolicyError as error:return json.dumps({'error':str(error)})
    except Exception:return json.dumps({'error':budget.failure or 'This source is unavailable, unsupported, or needs sign-in. Try another public link.'})
    finally:budget.close()
