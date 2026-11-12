import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {mkdtemp,readdir,rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {LocalEngine} from '../src/engine.mjs';

test('failed engine extraction removes its unactivated managed directory',async t=>{
  const dir=await mkdtemp(path.join(os.tmpdir(),'turbosave-tool-cleanup-'));
  t.after(()=>rm(dir,{recursive:true,force:true}));
  const engine=new LocalEngine({toolsDir:dir,stateDir:dir,downloadsDir:dir});
  engine.run=async()=>{throw Error('invalid archive fixture');};
  const bytes=Buffer.from('invalid archive fixture');
  const sha256=createHash('sha256').update(bytes).digest('hex');
  await assert.rejects(()=>engine.toolStore.install('ffmpeg',bytes,{version:'9.0.2',sha256}),/invalid archive fixture/);
  assert.deepEqual(await readdir(path.join(dir,'managed-tools')),[]);
  assert.deepEqual(engine.toolStore.records,{});
});
