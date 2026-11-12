// SPDX-License-Identifier: GPL-3.0-only
// All cookie data and Firefox profiles in this check are synthetic and isolated.
import assert from 'node:assert/strict';import path from 'node:path';
import {mkdir,writeFile,readFile,readdir} from 'node:fs/promises';
import {YouTubeSession,firefoxProfiles,sessionRequired} from './youtube-session.mjs';
export async function youtubeSelfTest(engine,window,firefoxRoot,crypto,artifacts){
  const checks=[],js=source=>window.webContents.executeJavaScript(source,true);
  await engine.finishOnboarding();
  const profile=path.join(firefoxRoot,'Profiles','synthetic');await mkdir(profile,{recursive:true});
  await writeFile(path.join(firefoxRoot,'profiles.ini'),'[Profile0]\nName=Synthetic test profile\nIsRelative=1\nPath=Profiles/synthetic\n');
  const file=path.join(profile,'cookies.sqlite'),fixture=`import {DatabaseSync} from 'node:sqlite';const db=new DatabaseSync(${JSON.stringify(file)});db.exec('CREATE TABLE moz_cookies (host TEXT,path TEXT,isSecure INTEGER,isHttpOnly INTEGER,expiry INTEGER,name TEXT,value TEXT,originAttributes TEXT)');const insert=db.prepare('INSERT INTO moz_cookies VALUES(?,?,?,?,?,?,?,?)');insert.run('.youtube.com','/',1,1,${Math.floor(Date.now()/1000)+3600},'SID','SYNTHETIC_YOUTUBE_SESSION_ONLY','');insert.run('.example.com','/',1,1,0,'SID','SYNTHETIC_UNRELATED_SITE','');db.close();`;
  await engine.run(engine.tool('node'),['--no-warnings','--input-type=module','--eval',fixture]);
  const profiles=await js('window.turbo.youtubeProfiles()');assert.equal(profiles.profiles.length,1);assert.deepEqual(Object.keys(profiles.profiles[0]).sort(),['id','name']);
  await js(`document.querySelector('[data-view="settings"]').click();document.querySelector('#youtube-connect').click()`);
  const deadline=Date.now()+10_000;while(!await js('document.querySelector("#youtube-profile").options.length')){if(Date.now()>deadline)throw Error('Connection guide did not load');await new Promise(r=>setTimeout(r,30));}
  assert.equal(await js('document.querySelector("#youtube-dialog").open'),true);await js('document.querySelector("#youtube-close").click()');checks.push({name:'Real renderer/preload exposes profile choices without paths or credentials and opens the connection guide',passed:true});
  await engine.youtube.connect((await firefoxProfiles(firefoxRoot))[0]);
  const encrypted=await readFile(engine.youtube.file);assert.equal(encrypted.includes('SYNTHETIC_YOUTUBE_SESSION_ONLY'),false);assert.equal(encrypted.includes('SYNTHETIC_UNRELATED_SITE'),false);
  assert.equal((await js('window.turbo.state()')).youtube.connected,true);assert.doesNotMatch(JSON.stringify(await js('window.turbo.state()')),/SYNTHETIC_YOUTUBE_SESSION_ONLY/);
  checks.push({name:'Packaged verified Node reads only YouTube cookies and Windows safeStorage encrypts the remembered session',passed:true});
  const restored=new YouTubeSession({stateDir:engine.stateDir,crypto,readBrowser:()=>{throw Error('Restore must not read browser cookies');}});await restored.restore();assert.equal(restored.snapshot().connected,true);checks.push({name:'Remembered session restores using Windows encryption without reading the browser again',passed:true});
  await engine.youtube.withCookies('https://www.youtube.com/watch?v=fixture',async temporary=>{const text=await readFile(temporary,'utf8');assert.match(text,/SYNTHETIC_YOUTUBE_SESSION_ONLY/);assert.doesNotMatch(text,/SYNTHETIC_UNRELATED_SITE/);});
  await engine.youtube.withCookies('https://example.com/',async temporary=>assert.equal(temporary,null));assert.equal((await readdir(engine.youtube.work)).length,0);checks.push({name:'Temporary session file contains only YouTube, is never used for other sites and is removed after use',passed:true});
  await assert.rejects(()=>engine.youtube.withCookies('https://www.youtube.com/watch?v=fixture',async()=>{throw sessionRequired();}),{code:'YOUTUBE_AUTH_REQUIRED'});assert.equal(engine.youtube.snapshot().needsReconnect,true);assert.equal((await readdir(engine.youtube.work)).length,0);checks.push({name:'Rejected session requests reconnection and cleans temporary credentials',passed:true});
  await js('window.turbo.disconnectYouTube()');assert.equal(engine.youtube.snapshot().connected,false);await assert.rejects(()=>readFile(engine.youtube.file),{code:'ENOENT'});assert.equal(await js('document.querySelector("#youtube-disconnect").hidden'),true);checks.push({name:'Disconnect through the real narrow bridge removes the saved session and updates Settings',passed:true});
  window.setSize(880,760);await js(`document.querySelector('#youtube-connect').click()`);await new Promise(r=>setTimeout(r,150));assert.equal(await js('document.documentElement.scrollWidth<=innerWidth'),true);await mkdir(artifacts,{recursive:true});await writeFile(path.join(artifacts,'youtube-connection-guide.png'),(await window.webContents.capturePage()).toPNG());await js('document.querySelector("#youtube-close").click()');
  return checks;
}
