import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {LocalEngine} from '../src/engine.mjs';

function gate(){let reject;const promise=new Promise((_,fail)=>{reject=fail;});return {promise,reject};}

test('a failed queue save cannot start a provisional download or erase history',async t=>{
  const dir=await mkdtemp(path.join(os.tmpdir(),'turbosave-queue-save-'));
  t.after(()=>rm(dir,{recursive:true,force:true}));
  const engine=new LocalEngine({toolsDir:dir,stateDir:dir,downloadsDir:dir});
  engine.jobs=Array.from({length:100},(_,index)=>({id:`old-${index}`,status:'completed',createdAt:index}));
  engine.media.set('media',{source:'https://example.com/video',title:'Fixture',platform:'Fixture',created:Date.now(),keys:[],formats:[{id:'0',selector:'v',extension:'mp4',kind:'video',quality:'720p'}]});
  engine.checkFolder=async()=>{};engine.library.known=async()=>[];
  let pumpCalls=0;engine.pump=async()=>{pumpCalls++;};
  const save=gate();engine.save=()=>save.promise;
  const adding=engine.enqueue({mediaId:'media',formatId:'0'});
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(engine.pending().length,0,'uncommitted work must not be runnable');
  save.reject(Error('state file could not be saved'));
  await assert.rejects(adding,/state file could not be saved/);
  assert.equal(engine.jobs.length,100);
  assert.equal(engine.jobs.some(job=>job.id.startsWith('old-')),true);
  assert.equal(engine.jobs.some(job=>job.source==='https://example.com/video'),false);
  assert.equal(engine.pending().length,0);
  assert.equal(pumpCalls,0);
});

test('a failed playlist save cannot feed an uncommitted group',async t=>{
  const dir=await mkdtemp(path.join(os.tmpdir(),'turbosave-playlist-save-'));
  t.after(()=>rm(dir,{recursive:true,force:true}));
  const engine=new LocalEngine({toolsDir:dir,stateDir:dir,downloadsDir:dir});
  engine.ready=true;engine.checkFolder=async()=>{};
  let pumpCalls=0;engine.pump=async()=>{pumpCalls++;};
  engine.playlists.previews.set('preview',{id:'preview',title:'Fixture',source:'https://www.youtube.com/playlist?list=PL1234567890',created:Date.now(),entries:[{key:'1',index:1,title:'Video',available:true,source:'https://www.youtube.com/watch?v=abcdefghijk'}]});
  const save=gate();engine.save=()=>save.promise;
  const starting=engine.playlists.start({id:'preview',keys:['1']});
  await new Promise(resolve=>setImmediate(resolve));
  engine.playlists.feed();
  assert.equal(engine.jobs.length,0,'uncommitted playlist must not create jobs');
  save.reject(Error('playlist state could not be saved'));
  await assert.rejects(starting,/playlist state could not be saved/);
  assert.equal(engine.playlists.groups.length,0);
  assert.equal(engine.jobs.length,0);
  assert.equal(pumpCalls,0);
});
