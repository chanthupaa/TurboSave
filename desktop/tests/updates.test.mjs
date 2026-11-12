import test from 'node:test';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {UpdateService,newer,checksumFor,githubBytes,desktopRepo} from '../src/updates.mjs';

test('desktop update discovery selects a newer installable Windows release only',async()=>{
 const asset=(version,tag,type='setup')=>({name:`TurboSave-Desktop-${version}-${type}.exe`,size:100,browser_download_url:`https://github.com/${desktopRepo}/releases/download/${tag}/TurboSave-Desktop-${version}-${type}.exe`});
 const releases=[
  {tag_name:'android-v9.0.0',assets:[asset('9.0.0','android-v9.0.0')]},
  {tag_name:'desktop-v0.9.0-source',assets:[]},
  {tag_name:'desktop-v0.8.0-beta.6',assets:[]},
  {tag_name:'desktop-v0.8.0-beta.5',assets:[asset('0.8.0-beta.5','desktop-v0.8.0-beta.5')]},
  {tag_name:'desktop-v0.8.0-beta.7',assets:[asset('0.8.0-beta.7','desktop-v0.8.0-beta.7','portable')]},
  {tag_name:'desktop-v1.0.0',draft:true,assets:[asset('1.0.0','desktop-v1.0.0')]}
 ];
 let requested;const service=new UpdateService({engine:{},appVersion:'0.8.0-beta.5',read:async url=>{requested=url;return Buffer.from(JSON.stringify(releases));}});
 const info=await service.check('app');assert.equal(requested,`https://api.github.com/repos/${desktopRepo}/releases?per_page=30`);assert.equal(info.available,true);assert.equal(info.latest,'0.8.0-beta.7');assert.equal(info.releaseUrl,`https://github.com/${desktopRepo}/releases/tag/desktop-v0.8.0-beta.7`);
 releases[4].assets[0].browser_download_url='https://evil.example/setup.exe';assert.equal((await service.check('app')).available,false);
});
test('source-only and Android releases do not claim a Windows update',async()=>{
 const service=new UpdateService({engine:{},appVersion:'0.8.0-beta.5',read:async()=>Buffer.from(JSON.stringify([{tag_name:'desktop-v0.8.0-beta.5-source',assets:[]},{tag_name:'android-v1.5.3-source',assets:[]}]))});
 const info=await service.check('app');assert.equal(info.available,false);assert.match(info.message,/No newer installable Windows release/);assert.equal(info.releaseUrl,undefined);
});
test('release comparisons and checksum parsing reject ambiguous update inputs',async()=>{
 assert.equal(newer('0.10.0','0.9.9'),true);assert.equal(newer('2026.10.26.1','2026.10.26'),true);assert.equal(newer('0.8.0-beta.6','0.8.0-beta.5'),true);assert.equal(newer('0.8.0','0.8.0-beta.5'),true);assert.equal(newer('0.8.0-beta.5','0.8.0'),false);assert.equal(newer('0.4.0','0.4.0'),false);assert.equal(newer('garbage','0.4.0'),false);
 const digest='a'.repeat(64);assert.equal(checksumFor(`${digest}  yt-dlp.exe\n`,'yt-dlp.exe'),digest);assert.throws(()=>checksumFor(`${digest}  other.exe`,'yt-dlp.exe'));
 for(const url of ['http://github.com/file','https://evil.example/file','https://github.com.evil.example/file','https://user:pass@github.com/file'])await assert.rejects(()=>githubBytes(url),/trusted/);
});
test('official engine update is checksum-verified before it can be installed',async()=>{
 const binary=Buffer.from('MZverified fixture'),hash=createHash('sha256').update(binary).digest('hex'),visits=[];let installed=false;
 const engine={settings:{},versions:{'yt-dlp':'2026.10.25'},assertIdleForUpdate(){},changed(){},pump(){},async installDownloader(bytes,version,digest){assert.deepEqual(bytes,binary);assert.equal(version,'2026.10.26');assert.equal(digest,hash);installed=true;}};
 const read=async url=>{visits.push(url);return url.includes('api.github.com')?Buffer.from(JSON.stringify({tag_name:'2026.10.26'})):url.endsWith('SHA2-256SUMS')?Buffer.from(`${hash}  yt-dlp.exe`):binary;};
 const service=new UpdateService({engine,appVersion:'0.5.0',read});assert.equal((await service.installDownloader()).installed,true);assert.equal(installed,true);assert.ok(visits.every(url=>url.startsWith('https://api.github.com/repos/yt-dlp/yt-dlp/')||url.startsWith('https://github.com/yt-dlp/yt-dlp/releases/download/')));assert.equal(engine.maintenance,false);
 installed=false;const tampered=new UpdateService({engine,appVersion:'0.5.0',read:async url=>url.endsWith('yt-dlp.exe')?Buffer.from('MZtampered'):read(url)});await assert.rejects(()=>tampered.installDownloader(),/verification failed/);assert.equal(installed,false);assert.equal(engine.maintenance,false);
});
