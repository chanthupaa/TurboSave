import test from 'node:test';import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,readdir,rm,symlink} from 'node:fs/promises';import {existsSync} from 'node:fs';
import {randomBytes,createCipheriv,createDecipheriv} from 'node:crypto';
import {execFile} from 'node:child_process';import {promisify} from 'node:util';
import path from 'node:path';import os from 'node:os';import {DatabaseSync} from 'node:sqlite';
import {YouTubeSession,sessionCookies,cookieJar,parseCookieJar,firefoxProfiles,sessionRequired} from '../src/youtube-session.mjs';
import {readFirefoxSession} from '../src/firefox-session-reader.mjs';
import {LocalEngine} from '../src/engine.mjs';import {diagnosticReport} from '../src/diagnostics.mjs';import {safeError} from '../src/media.mjs';
const video='https://www.youtube.com/watch?v=SfbOn9j2Tro';
const rows=()=>[{domain:'.youtube.com',path:'/',secure:1,httpOnly:1,expires:Math.floor(Date.now()/1000)+3600,name:'SID',value:'SYNTHETIC_SESSION_ONLY'},
  {domain:'.example.com',path:'/',secure:1,httpOnly:0,expires:0,name:'other',value:'UNRELATED_SITE_NEVER_READ'}];
function cryptoAdapter(){const key=randomBytes(32);return {available:async()=>true,encrypt:async text=>{const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',key,iv);const data=Buffer.concat([cipher.update(text,'utf8'),cipher.final()]);return Buffer.concat([iv,cipher.getAuthTag(),data]);},decrypt:async bytes=>{const cipher=createDecipheriv('aes-256-gcm',key,bytes.subarray(0,12));cipher.setAuthTag(bytes.subarray(12,28));return Buffer.concat([cipher.update(bytes.subarray(28)),cipher.final()]).toString('utf8');}};}
async function fixture(t){const dir=await mkdtemp(path.join(os.tmpdir(),'turbosave-youtube-'));t.after(()=>rm(dir,{recursive:true,force:true}));const crypto=cryptoAdapter();let reads=0;const options={stateDir:dir,crypto,readBrowser:async()=>{reads++;return rows();}},session=new YouTubeSession(options);await session.restore();return {dir,session,options,reads:()=>reads};}

test('connection is opt-in, YouTube-only, encrypted, restored without another browser read and removed by Disconnect',async t=>{
  const f=await fixture(t);await f.session.withCookies(video,async file=>assert.equal(file,null));assert.equal(f.reads(),0);
  await f.session.connect({id:'fixture'});assert.equal(f.reads(),1);assert.equal(f.session.snapshot().connected,true);
  const bytes=await readFile(f.session.file);assert.ok(!bytes.includes('SYNTHETIC_SESSION_ONLY'));assert.ok(!bytes.includes('UNRELATED_SITE_NEVER_READ'));
  let used;await f.session.withCookies(video,async file=>{used=file;const jar=await readFile(file,'utf8');assert.match(jar,/#HttpOnly_\.youtube\.com/);assert.match(jar,/SYNTHETIC_SESSION_ONLY/);assert.doesNotMatch(jar,/UNRELATED_SITE_NEVER_READ/);});await assert.rejects(()=>readFile(used),{code:'ENOENT'});
  const restored=new YouTubeSession(f.options);await restored.restore();assert.equal(restored.snapshot().connected,true);assert.equal(f.reads(),1);
  for(const url of ['https://example.com/','https://youtube.com.evil.test/','https://youtube.com@evil.test/','http://youtube.com/'])await restored.withCookies(url,async file=>assert.equal(file,null));
  const engine=new LocalEngine({stateDir:f.dir,toolsDir:f.dir,downloadsDir:f.dir});engine.youtube=restored;assert.doesNotMatch(JSON.stringify(engine.snapshot()),/SYNTHETIC_SESSION_ONLY|UNRELATED_SITE_NEVER_READ/);assert.doesNotMatch(JSON.stringify(diagnosticReport(engine,'test')),/session|cookie|SYNTHETIC_SESSION_ONLY/i);
  await restored.disconnect();await assert.rejects(()=>readFile(restored.file),{code:'ENOENT'});assert.equal(restored.snapshot().connected,false);
});
test('cookie validation rejects expired accounts, line injection and oversized jars',()=>{
  assert.equal(parseCookieJar(cookieJar(sessionCookies(rows()))).length,1);
  assert.throws(()=>sessionCookies([{...rows()[0],expires:1}]),/Sign in/);
  assert.throws(()=>sessionCookies([{...rows()[0],value:'bad\n.example.com\tTRUE'}]),/invalid/);
  assert.throws(()=>sessionCookies(Array(401).fill(rows()[0])),/large/);
  assert.throws(()=>sessionCookies([{...rows()[0],domain:'.youtube.com.evil.test'}]),/Sign in/);
});
test('the actual bundled yt-dlp consumes the generated cookie jar offline',{skip:!existsSync(path.resolve('vendor/bin/yt-dlp.exe'))},async t=>{
  const f=await fixture(t);await f.session.connect({});const info=path.join(f.dir,'fixture.json');await writeFile(info,JSON.stringify({id:'synthetic-cookie-check',title:'Synthetic cookie check',extractor:'generic',extractor_key:'Generic',webpage_url:'https://example.com/fixture',formats:[{format_id:'fixture',url:'https://example.com/fixture.mp4',ext:'mp4',vcodec:'h264',acodec:'aac'}]}));
  const engine=new LocalEngine({toolsDir:path.resolve('vendor'),stateDir:f.dir,downloadsDir:f.dir});
  await f.session.withCookies(video,async file=>{const result=await engine.run(engine.tool('yt-dlp'),['--ignore-config','--no-plugin-dirs','--cookies',file,'--load-info-json',info,'--simulate','--skip-download','--print','%(id)s'],{timeout:20000});assert.equal(result.trim(),'synthetic-cookie-check');});assert.equal((await readdir(f.session.work)).length,0);
});
test('unavailable encryption and corrupt saved sessions fail closed',async t=>{
  const f=await fixture(t);const unavailable=new YouTubeSession({...f.options,crypto:{available:async()=>false}});await assert.rejects(()=>unavailable.connect({}),/encryption/);assert.equal(f.reads(),0);
  await writeFile(f.session.file,'not encrypted');await f.session.restore();assert.equal(f.session.snapshot().connected,false);assert.match(f.session.snapshot().warning,/cannot be used/);
});
test('verification stops repeated authenticated requests and cleanup runs on failure and crash recovery',async t=>{
  const f=await fixture(t);await f.session.connect({});let requests=0;
  await assert.rejects(()=>f.session.withCookies(video,async()=>{requests++;throw sessionRequired();}),{code:'YOUTUBE_AUTH_REQUIRED'});
  assert.equal(f.session.snapshot().needsReconnect,true);assert.equal((await readdir(f.session.work)).length,0);
  await assert.rejects(()=>f.session.withCookies(video,async()=>requests++),{code:'YOUTUBE_AUTH_REQUIRED'});assert.equal(requests,1);
  const restored=new YouTubeSession(f.options);const leftover=path.join(f.session.work,'cookies-'+randomBytes(16).toString('hex').replace(/(.{8})(.{4})(.{4})(.{4})(.{12})/,'$1-$2-$3-$4-$5')+'.txt');await writeFile(leftover,cookieJar(sessionCookies(rows())));await restored.restore();await assert.rejects(()=>readFile(leftover),{code:'ENOENT'});assert.equal(restored.snapshot().needsReconnect,true);
  await restored.connect({});assert.equal(restored.snapshot().needsReconnect,false);await restored.withCookies(video,async file=>{const updated=await readFile(file,'utf8');await writeFile(file,updated.replace('SYNTHETIC_SESSION_ONLY','SYNTHETIC_ROTATED'));});await restored.withCookies(video,async file=>assert.match(await readFile(file,'utf8'),/SYNTHETIC_ROTATED/));
});
test('Disconnect during an outstanding request cannot resurrect its saved credentials',async t=>{
  const f=await fixture(t);await f.session.connect({});let finish,started;const ready=new Promise(r=>started=r);const request=f.session.withCookies(video,async()=>{started();await new Promise(r=>finish=r);});await ready;await f.session.disconnect();finish();await request;assert.equal(f.session.snapshot().connected,false);await assert.rejects(()=>readFile(f.session.file),{code:'ENOENT'});
});
test('rotated Firefox credentials refresh once automatically after consent; repeated rejection never loops',async t=>{
  const f=await fixture(t),browserCookie=rows()[0];let reads=0;const session=new YouTubeSession({...f.options,readBrowser:async()=>[{...browserCookie,value:++reads===1?'SYNTHETIC_OLD':'SYNTHETIC_NEW'}]});await session.restore();await session.connect({id:'Profile0'});let requests=0;
  const result=await session.withCookies(video,async file=>{requests++;if((await readFile(file,'utf8')).includes('SYNTHETIC_OLD'))throw sessionRequired();return 'saved';});assert.equal(result,'saved');assert.equal(reads,2);assert.equal(requests,2);assert.equal(session.snapshot().needsReconnect,false);assert.equal((await readdir(session.work)).length,0);
  requests=0;await assert.rejects(()=>session.withCookies(video,async()=>{requests++;throw sessionRequired();}),{code:'YOUTUBE_AUTH_REQUIRED'});assert.equal(requests,1);assert.equal(session.snapshot().needsReconnect,true);
});
test('Firefox helper selects only YouTube, leaves browser data unchanged and rejects redirected profiles',async t=>{
  const f=await fixture(t),root=path.join(f.dir,'Firefox'),profile=path.join(root,'Profiles','fixture');await mkdir(profile,{recursive:true});const file=path.join(profile,'cookies.sqlite');
  const db=new DatabaseSync(file);db.exec('CREATE TABLE moz_cookies (host TEXT,path TEXT,isSecure INTEGER,isHttpOnly INTEGER,expiry INTEGER,name TEXT,value TEXT,originAttributes TEXT)');
  const insert=db.prepare('INSERT INTO moz_cookies VALUES(?,?,?,?,?,?,?,?)');for(const row of rows())insert.run(row.domain,row.path,row.secure,row.httpOnly,row.expires,row.name,row.value,'');insert.run('.youtube.com','/',1,1,0,'SID','SYNTHETIC_OTHER_CONTAINER','^userContextId=1');db.close();
  await writeFile(path.join(root,'profiles.ini'),'[Profile0]\nName=Testing\nIsRelative=1\nPath=Profiles/fixture\n[Profile1]\nName=Escape\nIsRelative=1\nPath=../outside\n');
  const before=await readFile(file),profiles=await firefoxProfiles(root);assert.equal(profiles.length,1);assert.equal(profiles[0].id,'Profile0');assert.equal(readFirefoxSession(file).length,1);
  const code=await readFile(new URL('../src/firefox-session-reader.mjs',import.meta.url),'utf8');const {stdout}=await promisify(execFile)(process.execPath,['--no-warnings','--permission','--allow-fs-read='+profile,'--input-type=module','--eval',code+'\nconsole.log(JSON.stringify(readFirefoxSession(process.argv[1])));','--',file]);assert.equal(JSON.parse(stdout).length,1);assert.doesNotMatch(stdout,/UNRELATED_SITE|OTHER_CONTAINER/);assert.deepEqual(await readFile(file),before);
  const redirected=path.join(root,'Profiles','redirected');await symlink(profile,redirected,process.platform==='win32'?'junction':'dir');await writeFile(path.join(root,'profiles.ini'),'[Profile0]\nName=Redirected\nIsRelative=1\nPath=Profiles/redirected\n');assert.deepEqual(await firefoxProfiles(root),[]);
});
test('engine attaches sessions only to YouTube yt-dlp requests, never other sites or tool processes',async t=>{
  const f=await fixture(t);await f.session.connect({});const engine=new LocalEngine({stateDir:f.dir,toolsDir:f.dir,downloadsDir:f.dir});engine.youtube=f.session;const calls=[];engine.runVerified=async(binary,args)=>{calls.push(args);if(args.includes('--cookies'))assert.match(await readFile(args[args.indexOf('--cookies')+1],'utf8'),/SYNTHETIC_SESSION_ONLY/);return 'ok';};
  await engine.run(engine.tool('yt-dlp'),['--ignore-config','--',video]);assert.equal(calls[0].at(-2),'--');assert.equal(calls[0].at(-1),video);assert.ok(calls[0].includes('--cookies'));
  await engine.run(engine.tool('yt-dlp'),['--','https://example.com/']);await engine.run(engine.tool('node'),['--',video]);assert.ok(!calls[1].includes('--cookies'));assert.ok(!calls[2].includes('--cookies'));assert.equal((await readdir(f.session.work)).length,0);
});
test('YouTube verification pauses the playlist with later entries pending; missing videos have a useful error',async t=>{
  const f=await fixture(t),engine=new LocalEngine({stateDir:f.dir,toolsDir:f.dir,downloadsDir:f.dir});engine.ready=true;engine.refreshJob=async()=>{throw sessionRequired();};
  engine.playlists.groups=[{id:'g',status:'running',preference:{kind:'video',height:1080},directory:f.dir,entries:[1,2].map(index=>({key:String(index),index,source:video,title:'Fixture',status:'pending'}))}];
  await engine.pump();assert.equal(engine.playlists.groups[0].status,'paused');assert.equal(engine.playlists.groups[0].entries[0].status,'paused');assert.equal(engine.playlists.groups[0].entries[1].status,'pending');assert.match(engine.jobs[0].message,/Settings/);await engine.close();
  assert.match(safeError('ERROR: Video unavailable. This video is not available'),/unavailable, private or removed/);
});
