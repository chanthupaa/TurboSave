// SPDX-License-Identifier: GPL-3.0-only
import https from 'node:https';import {createHash} from 'node:crypto';import {publicTarget} from './media.mjs';
import {readFile,writeFile} from 'node:fs/promises';import path from 'node:path';
const hosts=new Set(['api.github.com','github.com','release-assets.githubusercontent.com','objects.githubusercontent.com','nodejs.org']);
export const desktopRepo='chanthupaa/TurboSave';
export function newer(latest,current){
  const parse=value=>{const match=String(value).replace(/^v/,'').match(/^(\d+)\.(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-beta\.(\d+))?$/);return match&&{parts:match.slice(1,5).map(v=>Number(v||0)),beta:match[5]===undefined?null:Number(match[5])};};
  const a=parse(latest),b=parse(current);if(!a||!b)return false;
  for(let i=0;i<4;i++)if(a.parts[i]!==b.parts[i])return a.parts[i]>b.parts[i];
  return a.beta===null&&b.beta!==null||a.beta!==null&&b.beta!==null&&a.beta>b.beta;
}
export function desktopRelease(releases,current){
  if(!Array.isArray(releases))throw Error('GitHub returned an invalid release list.');
  let best;
  for(const release of releases){
    const tag=release?.tag_name,match=typeof tag==='string'&&tag.match(/^desktop-v(\d+\.\d+\.\d+(?:-beta\.\d+)?)$/);
    if(!match||release.draft||!newer(match[1],current))continue;
    const assets=release.assets;if(!Array.isArray(assets))continue;
    const base=`https://github.com/${desktopRepo}/releases/download/${encodeURIComponent(tag)}/`;
    const binaries=assets.filter(asset=>['setup','portable'].some(type=>asset?.name===`TurboSave-Desktop-${match[1]}-${type}.exe`)&&Number.isSafeInteger(asset.size)&&asset.size>0&&asset.browser_download_url===base+asset.name);
    if(!binaries.length)continue;
    if(!best||newer(match[1],best.latest))best={kind:'app',current,latest:match[1],tag,available:true,releaseUrl:`https://github.com/${desktopRepo}/releases/tag/${encodeURIComponent(tag)}`};
  }
  return best||{kind:'app',current,available:false,message:'No newer installable Windows release is published yet. Source-only and Android releases are excluded.'};
}
export async function githubBytes(value,{limit=2_000_000,signal=AbortSignal.timeout(20_000)}={}){
  for(let hop=0;hop<5;hop++){
    const parsed=new URL(value);if(parsed.protocol!=='https:'||!hosts.has(parsed.hostname)||parsed.username||parsed.password||parsed.port)throw Error('Update host is not trusted.');
    signal.throwIfAborted();let onAbort;
    const aborted=new Promise((_,reject)=>{onAbort=()=>reject(signal.reason);signal.addEventListener('abort',onAbort,{once:true});});
    let target;try{target=await Promise.race([publicTarget(parsed.href),aborted]);}finally{signal.removeEventListener('abort',onAbort);}
    const result=await new Promise((resolve,reject)=>{
      const request=https.request(target.url,{signal,headers:{'User-Agent':'TurboSave-Desktop','Accept':parsed.hostname==='api.github.com'?'application/vnd.github+json':'application/octet-stream'},lookup(_host,options,callback){options?.all?callback(null,target.addresses):callback(null,target.addresses[0].address,target.addresses[0].family);}},response=>{
        response.on('error',reject);if([301,302,303,307,308].includes(response.statusCode)&&response.headers.location){response.destroy();resolve({redirect:new URL(response.headers.location,parsed).href});return;}
        if(response.statusCode!==200){response.destroy();reject(Error(`Update service returned HTTP ${response.statusCode}. Check the repository, connection or GitHub rate limit.`));return;}
        if(Number(response.headers['content-length'])>limit){response.destroy();reject(Error('Update response is too large.'));return;}
        let size=0;const chunks=[];response.on('data',chunk=>{size+=chunk.length;if(size>limit){response.destroy();reject(Error('Update response is too large.'));}else chunks.push(chunk);});
        response.on('end',()=>resolve({bytes:Buffer.concat(chunks)}));response.on('aborted',()=>reject(Error('Update download was interrupted.')));
      });request.on('error',reject);request.end();
    });if(result.bytes)return result.bytes;value=result.redirect;
  }throw Error('Too many update redirects.');
}
export function checksumFor(text,name){const line=String(text).split(/\r?\n/).find(line=>new RegExp(`^[a-fA-F0-9]{64}\\s+\\*?${name.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}$`).test(line.trim()));if(!line)throw Error('The official release has no matching SHA-256 checksum.');return line.trim().slice(0,64).toLowerCase();}
export class UpdateService{
  constructor({engine,appVersion,read=githubBytes}){this.engine=engine;this.appVersion=appVersion;this.read=read;this.busy=false;}
  async check(kind){
    if(['ffmpeg','node'].includes(kind))return this.toolRelease(kind);
    if(!['app','yt-dlp'].includes(kind))throw Error('Unknown update type.');
    if(kind==='app'){
      const releases=JSON.parse((await this.read(`https://api.github.com/repos/${desktopRepo}/releases?per_page=30`)).toString('utf8'));
      return desktopRelease(releases,this.appVersion);
    }
    const repo='yt-dlp/yt-dlp';
    const release=JSON.parse((await this.read(`https://api.github.com/repos/${repo}/releases/latest`)).toString('utf8'));
    const tag=String(release.tag_name||''),version=tag.replace(/^v/,'');
    if(release.draft||release.prerelease||!/^\d{4}\.\d{2}\.\d{2}(?:\.\d+)?$/.test(version))throw Error('The release version could not be verified.');
    const current=kind==='app'?this.appVersion:this.engine.versions['yt-dlp'];
    return {kind,configured:true,current,latest:version,tag,available:current==='Not available'||!current||newer(version,current),releaseUrl:`https://github.com/${repo}/releases/tag/${encodeURIComponent(tag)}`};
  }
  async toolRelease(kind){
    const current=this.engine.versions[kind]||'Not available';
    if(kind==='node'){
      const sums=(await this.read('https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt')).toString('utf8'),match=sums.match(/^([a-f0-9]{64})\s+(node-(v24\.\d+\.\d+)-win-x64\.zip)\s*$/m);
      if(!match)throw Error('The Node publisher checksum is unavailable.');
      return {kind,current,latest:match[3],url:`https://nodejs.org/dist/${match[3]}/${match[2]}`,sha256:match[1],available:current==='Not available'||newer(match[3],current)};
    }
    const release=JSON.parse((await this.read('https://api.github.com/repos/GyanD/codexffmpeg/releases/latest')).toString('utf8'));
    const version=String(release.tag_name||'').replace(/^v/,'');if(release.draft||release.prerelease||!/^\d+\.\d+(?:\.\d+)?$/.test(version))throw Error('The FFmpeg release version is invalid.');
    const asset=release.assets?.find(a=>a.name===`ffmpeg-${version}-essentials_build.zip`);
    if(!asset||!/^sha256:[a-f0-9]{64}$/.test(asset.digest||'')||asset.browser_download_url!==`https://github.com/GyanD/codexffmpeg/releases/download/${encodeURIComponent(release.tag_name)}/${asset.name}`)throw Error('The FFmpeg publisher checksum is unavailable.');
    return {kind,current,latest:version,url:asset.browser_download_url,sha256:asset.digest.slice(7),available:current==='Not available'||newer(version,current.match(/^ffmpeg version ([\d.]+)/)?.[1]||'0')};
  }
  async dailyCheck({force=false}={}){
    if(!force&&!this.engine.settings.dailyEngineChecks)return;
    const file=path.join(this.engine.stateDir,'engine-check.json');let record;try{record=JSON.parse(await readFile(file,'utf8'));}catch{}
    if(!force&&record&&Date.now()-record.checkedAt<24*60*60_000){this.engine.engineUpdates=record;this.engine.changed();return record;}
    const recordNext={checkedAt:Date.now(),results:[]};
    for(const kind of ['yt-dlp','ffmpeg','node'])try{const info=await this.check(kind);const {url,sha256,...publicInfo}=info;recordNext.results.push(publicInfo);}catch{recordNext.results.push({kind,error:'Update check unavailable. Your current engines were kept.'});}
    await writeFile(file,JSON.stringify(recordNext),{mode:0o600});this.engine.engineUpdates=recordNext;this.engine.changed();return recordNext;
  }
  async installTool(kind,{force=false}={}){
    if(kind==='yt-dlp')return this.installDownloader();
    if(this.busy)throw Error('An engine update is already running.');this.engine.assertIdleForUpdate();this.busy=true;this.engine.maintenance=true;
    try{
      const info=await this.check(kind);if(!force&&!info.available)return {message:'No newer stable release is available.'};
      this.engine.toolStatus=`Downloading and verifying ${kind} ${info.latest}…`;this.engine.changed();
      const bytes=await this.read(info.url,{limit:300_000_000,signal:AbortSignal.timeout(300_000)});
      await this.engine.toolStore.install(kind,bytes,{version:info.latest,sha256:info.sha256});
      return {installed:true,message:`Verified ${kind} ${info.latest} is ready.`};
    }finally{this.busy=false;this.engine.maintenance=false;this.engine.toolStatus=null;this.engine.changed();void this.engine.pump();}
  }
  async repair(){
    if(this.repairing)return;this.repairing=true;
    try{for(const kind of ['yt-dlp','ffmpeg','node'])if(this.engine.versions[kind]==='Not available'||kind==='ffmpeg'&&this.engine.versions.ffprobe==='Not available')await this.installTool(kind,{force:true});
      this.engine.ready=Object.values(this.engine.versions).length===4&&Object.values(this.engine.versions).every(v=>v!=='Not available');this.engine.engineUpdateWarning=null;
    }catch{this.engine.engineUpdateWarning='Automatic repair could not finish. Check your connection, then choose Repair missing tools in Settings.';}
    finally{this.repairing=false;this.engine.changed();}
  }
  async rollback(kind){
    if(kind==='yt-dlp')return this.engine.useBundledDownloader();
    this.engine.assertIdleForUpdate();this.engine.maintenance=true;this.engine.changed();
    try{await this.engine.toolStore.rollback(kind);}finally{this.engine.maintenance=false;this.engine.changed();void this.engine.pump();}
  }
  async installDownloader(){
    if(this.busy)throw Error('An engine update is already running.');this.engine.assertIdleForUpdate();this.busy=true;this.engine.maintenance=true;this.engine.changed();
    try{
      const info=await this.check('yt-dlp');if(!info.available)return {...info,message:'No newer stable downloader release is available.'};
      const base=`https://github.com/yt-dlp/yt-dlp/releases/download/${encodeURIComponent(info.tag)}/`;
      const expected=checksumFor((await this.read(base+'SHA2-256SUMS')).toString('utf8'),'yt-dlp.exe');
      const bytes=await this.read(base+'yt-dlp.exe',{limit:80_000_000,signal:AbortSignal.timeout(120_000)});
      if(createHash('sha256').update(bytes).digest('hex')!==expected||bytes.toString('ascii',0,2)!=='MZ')throw Error('Downloader verification failed. The current engine was kept.');
      await this.engine.installDownloader(bytes,info.latest,expected);return {...info,installed:true,message:`Verified yt-dlp ${info.latest} is ready.`};
    }finally{this.busy=false;this.engine.maintenance=false;this.engine.changed();void this.engine.pump();}
  }
}
