// SPDX-License-Identifier: GPL-3.0-only
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {mkdir,readFile,writeFile,rename,rm,readdir,lstat,realpath} from 'node:fs/promises';

const authNames=new Set(['SID','__Secure-1PSID','__Secure-3PSID']);
const cookieDomain=value=>typeof value==='string'&&/^(?:\.)?(?:[a-z0-9-]+\.)*youtube\.com$/.test(value);
const cleanText=value=>typeof value==='string'&&value.length<=16384&&!/[\x00-\x1f\x7f]/.test(value);
export function youtubeSource(value){try{const url=new URL(value);return url.protocol==='https:'&&!url.username&&!url.password&&!url.port&&['youtube.com','www.youtube.com','m.youtube.com','music.youtube.com','youtu.be'].includes(url.hostname);}catch{return false;}}
export function sessionRequired(){const error=Error('YouTube needs verification. Open Settings → YouTube connection to connect or reconnect, then retry.');error.code='YOUTUBE_AUTH_REQUIRED';return error;}
export function sessionCookies(rows,now=Math.floor(Date.now()/1000)){
  if(!Array.isArray(rows)||rows.length>400)throw Error('The YouTube session is too large.');
  const cookies=rows.filter(c=>c&&cookieDomain(c.domain)&&Number.isSafeInteger(c.expires)&&c.expires>=0&&(!c.expires||c.expires>now))
    .map(c=>{if(!cleanText(c.name)||!c.name||!cleanText(c.value)||!cleanText(c.path)||!c.path.startsWith('/'))throw Error('The YouTube session is invalid.');return {domain:c.domain,path:c.path,secure:Boolean(c.secure),httpOnly:Boolean(c.httpOnly),expires:c.expires,name:c.name,value:c.value};});
  if(!cookies.some(c=>authNames.has(c.name)&&c.value))throw Error('Sign in to YouTube in the selected Firefox profile first, then choose Remember this session.');
  return cookies;
}
export function cookieJar(cookies){return '# Netscape HTTP Cookie File\n'+cookies.map(c=>[`${c.httpOnly?'#HttpOnly_':''}${c.domain}`,c.domain.startsWith('.')?'TRUE':'FALSE',c.path,c.secure?'TRUE':'FALSE',c.expires,c.name,c.value].join('\t')).join('\n')+'\n';}
export function parseCookieJar(text){
  if(typeof text!=='string'||Buffer.byteLength(text)>1024*1024)throw Error('Invalid session file.');
  const rows=[];for(let line of text.split(/\r?\n/)){const httpOnly=line.startsWith('#HttpOnly_');if(httpOnly)line=line.slice(10);else if(!line||line.startsWith('#'))continue;const fields=line.split('\t');if(fields.length!==7)continue;const [domain,,cookiePath,secure,expires,name,value]=fields;rows.push({domain,path:cookiePath,secure:secure==='TRUE',httpOnly,expires:expires===''?0:Number(expires),name,value});}
  return sessionCookies(rows);
}
async function regular(file,max){const info=await lstat(file);if(!info.isFile()||info.isSymbolicLink()||info.size>max)throw Error('Invalid session file.');return info;}

export async function firefoxProfiles(root){
  let ini;try{await regular(path.join(root,'profiles.ini'),65536);ini=await readFile(path.join(root,'profiles.ini'),'utf8');}catch{return [];}
  const sections=[];let section;
  for(const line of ini.split(/\r?\n/)){const heading=line.trim().match(/^\[(Profile\d+)\]$/);if(heading){section={id:heading[1]};sections.push(section);}else if(/^\[/.test(line.trim()))section=null;else if(section){const match=line.match(/^([^=]+)=(.*)$/);if(match)section[match[1].trim()]=match[2].trim();}}
  const profiles=[];const actualRoot=await realpath(root);
  for(const item of sections){try{
    if(item.IsRelative!=='1'||!item.Path||path.isAbsolute(item.Path)||item.Path.split(/[\\/]/).some(p=>p==='..'))continue;
    const directory=path.resolve(root,item.Path),actual=await realpath(directory),info=await lstat(directory);
    if(!actual.startsWith(actualRoot+path.sep)||info.isSymbolicLink()||!info.isDirectory())continue;
    const database=path.join(directory,'cookies.sqlite');await regular(database,100*1024*1024);
    if(await realpath(database)!==path.join(actual,'cookies.sqlite'))continue;
    const name=String(item.Name||item.id).replace(/[\x00-\x1f\x7f]/g,'').slice(0,80);
    profiles.push({id:item.id,name,directory,database});
  }catch{}}
  return profiles;
}

export class YouTubeSession{
  #record=null;#generation=0;#pending=Promise.resolve();
  constructor({stateDir,crypto,readBrowser,onChange=()=>{}}){this.stateDir=stateDir;this.crypto=crypto;this.readBrowser=readBrowser;this.onChange=onChange;this.file=path.join(stateDir,'youtube-session.enc');this.work=path.join(stateDir,'youtube-session-work');this.warning=null;}
  snapshot(){return {connected:Boolean(this.#record),needsReconnect:Boolean(this.#record?.needsReconnect),connectedAt:this.#record?.connectedAt||null,warning:this.warning};}
  async workspace(){await mkdir(this.work,{recursive:true,mode:0o700});const info=await lstat(this.work);if(!info.isDirectory()||info.isSymbolicLink()||path.dirname(await realpath(this.work))!==await realpath(this.stateDir))throw Error('The private session folder is unavailable.');}
  async restore(){
    try{await this.workspace();for(const name of await readdir(this.work))if(/^cookies-[0-9a-f-]{36}\.txt$/.test(name)){const file=path.join(this.work,name);await regular(file,1024*1024);await rm(file);}}
    catch{this.warning='A temporary session file could not be cleaned. Close other TurboSave windows and restart.';return;}
    try{
      await regular(this.file,2*1024*1024);if(!await this.crypto.available())throw Error();
      const record=JSON.parse(await this.crypto.decrypt(await readFile(this.file)));
      if(record.schema!==1||!Number.isFinite(record.connectedAt))throw Error();
      try{record.cookies=sessionCookies(record.cookies);}catch{record.cookies=[];record.needsReconnect=true;}
      this.#record=record;
    }catch(error){if(error.code!=='ENOENT')this.warning='The saved YouTube session cannot be used. Connect again in Settings.';}
  }
  async persist(){
    const generation=this.#generation,record=this.#record;
    this.#pending=this.#pending.catch(()=>{}).then(async()=>{
      if(generation!==this.#generation)return;
      if(!record){await rm(this.file,{force:true});return;}
      if(!await this.crypto.available())throw Error('Windows encryption is unavailable. The session was not saved.');
      const bytes=await this.crypto.encrypt(JSON.stringify(record)),temporary=this.file+'.'+randomUUID()+'.tmp';
      try{await writeFile(temporary,bytes,{flag:'wx',mode:0o600});if(generation===this.#generation)await rename(temporary,this.file);}finally{await rm(temporary,{force:true});}
    });return this.#pending;
  }
  async connect(profile){
    if(!await this.crypto.available())throw Error('Windows encryption is unavailable. The session was not saved.');
    const cookies=sessionCookies(await this.readBrowser(profile)),previous=this.#record;
    this.#generation++;this.#record={schema:1,cookies,profileId:profile.id,connectedAt:Date.now(),needsReconnect:false};
    try{await this.persist();}catch(error){this.#record=previous;throw error;}
    this.warning=null;this.onChange();return this.snapshot();
  }
  async disconnect(){const previous=this.#record;this.#generation++;this.#record=null;try{await this.persist();}catch(error){this.#record=previous;throw error;}this.warning=null;this.onChange();return this.snapshot();}
  async refresh(cookies){
    const generation=this.#generation,id=this.#record?.profileId;if(!/^Profile\d+$/.test(id||''))return false;
    try{
      const fresh=sessionCookies(await this.readBrowser({id}));
      if(generation!==this.#generation||!this.#record||cookieJar(fresh)===cookieJar(cookies))return false;
      this.#generation++;this.#record.cookies=fresh;this.#record.needsReconnect=false;await this.persist();this.onChange();return true;
    }catch{return false;}
  }
  async withCookies(source,run,refreshed=false){
    if(!youtubeSource(source)||!this.#record)return run(null);
    const generation=this.#generation;
    if(this.#record.needsReconnect){if(!refreshed&&await this.refresh(this.#record.cookies))return this.withCookies(source,run,true);throw sessionRequired();}
    let cookies;try{cookies=sessionCookies(this.#record.cookies);}catch{if(!refreshed&&await this.refresh(this.#record.cookies))return this.withCookies(source,run,true);if(generation===this.#generation&&this.#record){this.#record.needsReconnect=true;await this.persist();this.onChange();}throw sessionRequired();}
    await this.workspace();const file=path.join(this.work,'cookies-'+randomUUID()+'.txt');
    try{
      await writeFile(file,cookieJar(cookies),{flag:'wx',mode:0o600});
      const result=await run(file);
      // yt-dlp may rotate cookies. Keep only YouTube values and preserve a concurrent reconnect warning.
      if(generation===this.#generation&&this.#record){try{await regular(file,1024*1024);this.#record.cookies=parseCookieJar(await readFile(file,'utf8'));await this.persist();}catch{this.warning='The session could not be refreshed. Reconnect if YouTube asks for verification.';this.onChange();}}
      return result;
    }catch(error){if(error.code==='YOUTUBE_AUTH_REQUIRED'&&generation===this.#generation&&this.#record){if(!refreshed&&await this.refresh(cookies))return this.withCookies(source,run,true);if(generation===this.#generation&&this.#record){this.#record.needsReconnect=true;await this.persist().catch(()=>{});this.onChange();}}throw error;}
    finally{try{await rm(file,{force:true,maxRetries:4,retryDelay:100});}catch{this.warning='A temporary session file could not be cleaned. Restart TurboSave to retry cleanup.';this.onChange();}}
  }
}
