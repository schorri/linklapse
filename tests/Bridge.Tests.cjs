// Offline HTTP integration. Never starts a measurement or invokes the update helper.
const assert=require('node:assert/strict'),fs=require('node:fs/promises'),path=require('node:path'),os=require('node:os'),http=require('node:http');
const {spawn}=require('node:child_process');
(async()=>{
 async function request(url,options){const response=await fetch(url,options);return {status:response.status,headers:response.headers,body:await response.text()};}
 const source=path.resolve(__dirname,'..'),scratch=await fs.mkdtemp(path.join(os.tmpdir(),'linklapse-bridge-'));
 let child;
 try{
  for(const dir of ['src','web','docs'])await fs.cp(path.join(source,dir),path.join(scratch,dir),{recursive:true});
  await fs.copyFile(path.join(source,'config.json'),path.join(scratch,'config.json'));
  const powershell=path.join(process.env.SystemRoot,'System32','WindowsPowerShell','v1.0','powershell.exe');
  const script=path.join(scratch,'src','UiHost.ps1').replace(/'/g,"''");
  child=spawn(powershell,['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-Command',"[Threading.Thread]::CurrentThread.CurrentUICulture=[Globalization.CultureInfo]::GetCultureInfo('de-DE'); & '"+script+"' -NoOpen -ExitAfterSeconds 45"],{windowsHide:true,stdio:'pipe'});
  let diagnostics='';child.stdout.on('data',x=>diagnostics+=x);child.stderr.on('data',x=>diagnostics+=x);
  const exit=new Promise(resolve=>child.once('exit',code=>resolve(code)));
  let instance;
  for(let i=0;i<150;i++){
   try{instance=JSON.parse((await fs.readFile(path.join(scratch,'data','ui-instance.json'),'utf8')).replace(/^\uFEFF/,''));break;}catch{}
   if(child.exitCode!==null)throw Error('Bridge exited early: '+diagnostics);
   await new Promise(r=>setTimeout(r,100));
  }
  assert.ok(instance,'Bridge readiness timed out: '+diagnostics);
  const url=instance.Url,root=await request(url);assert.equal(root.status,200);assert.match(root.headers.get('content-type'),/text\/html/);assert.equal(root.headers.get('content-disposition'),null);
  assert.equal(root.headers.get('x-frame-options'),'DENY');
  assert.equal((await request(url+'/guide/en')).status,200);
  assert.equal((await request(url+'/guide/configuration.html')).status,200);
  const html=root.body,token=JSON.parse(html.match(/<script id="measurement-data" type="application\/json">([\s\S]*?)<\/script>/)[1]).extra.Token;
  const boot=JSON.parse(html.match(/<script id="measurement-data" type="application\/json">([\s\S]*?)<\/script>/)[1]);
  assert.equal(boot.extra.Settings.Language,'en','English must remain the default under German Windows UI culture');
  assert.equal(boot.extra.Preferences.Language,'en');
  assert.equal((await request(url+'/api/state')).status,403);
  assert.equal((await request(url+'/api/state',{headers:{'X-LinkLapse-Token':token,Origin:'https://example.invalid'}})).status,403);
  assert.equal((await request(url+'/api/start',{method:'POST',headers:{'Content-Type':'application/json','X-LinkLapse-Token':token},body:'{}'})).status,403);
  const badHost=await new Promise((resolve,reject)=>{http.get(url,{headers:{Host:'example.invalid'}},r=>{r.resume();resolve(r.statusCode)}).on('error',reject)});assert.equal(badHost,403);
  assert.equal((await request(url+'/src/UiHost.ps1')).status,404);
  assert.equal((await request(url+'/config.json')).status,404);
  const headers={Origin:url,'Content-Type':'application/json','X-LinkLapse-Token':token};
  assert.equal((await request(url+'/api/start',{method:'POST',headers,body:'{}'})).status,400);
  const boundary=JSON.stringify({text:'x'.repeat(16373)});assert.equal(Buffer.byteLength(boundary),16384);
  assert.equal((await request(url+'/api/start',{method:'POST',headers,body:boundary})).status,400,'16 KiB reaches settings validation rather than the size rejection');
  for(let attempt=0;attempt<20;attempt++){
   const rejected=await request(url+'/api/start',{method:'POST',headers,body:JSON.stringify({text:'x'.repeat(17000)})});
   assert.equal(rejected.status,413);assert.equal(rejected.body,'Invalid body size');
  }
  // Spread an oversized upload across packets so the server cannot rely on one read.
  const fragmented=await new Promise((resolve,reject)=>{
   const payload=JSON.stringify({text:'x'.repeat(17000)});
   const req=http.request(url+'/api/start',{method:'POST',headers:{...headers,'Content-Length':Buffer.byteLength(payload)}},res=>{
    let body='';res.setEncoding('utf8');res.on('data',chunk=>body+=chunk);
    res.on('error',reject);res.on('end',()=>resolve({status:res.statusCode,body}));
   });
   req.on('error',reject);req.setTimeout(5000,()=>req.destroy(Error('Fragmented request timed out')));
   req.flushHeaders();let offset=0;
   const send=()=>{if(req.destroyed)return;if(offset>=payload.length){req.end();return;}req.write(payload.slice(offset,offset+1024));offset+=1024;setTimeout(send,10);};
   send();
  });
  assert.equal(fragmented.status,413);assert.equal(fragmented.body,'Invalid body size');
  // A client declaring an oversized body but withholding it cannot hold a worker indefinitely.
  const stalled=await new Promise((resolve,reject)=>{
   const req=http.request(url+'/api/start',{method:'POST',headers:{...headers,'Content-Length':17000}},res=>{
    let body='';res.setEncoding('utf8');res.on('data',chunk=>body+=chunk);res.on('error',reject);
    res.on('end',()=>resolve({status:res.statusCode,body}));
   });
   req.on('error',reject);req.setTimeout(4000,()=>req.destroy(Error('Rejected upload drain exceeded its deadline')));req.end();
  });
  assert.equal(stalled.status,413);assert.equal(stalled.body,'Invalid body size');
  const state=JSON.parse((await request(url+'/api/state',{headers:{'X-LinkLapse-Token':token}})).body);assert.equal(state.control.Phase,'idle');assert.equal(state.measurement,null);
  assert.equal((await request(url+'/api/close',{method:'POST',headers,body:'{}'})).status,200);
  const code=await exit;assert.equal(code,0,diagnostics);
  console.log('PASS: loopback HTTP, HTML content disposition, token/origin/host gates, path allowlist, complete responses, repeated/fragmented oversized bodies, bounded discard deadline, invalid settings, graceful shutdown. No measurement or policy action.');
 }finally{
  if(child&&child.exitCode===null){child.kill();await new Promise(r=>child.once('exit',r));}
  const resolved=path.resolve(scratch),allowed=path.resolve(os.tmpdir())+path.sep;
  if(!resolved.startsWith(allowed)||!path.basename(resolved).startsWith('linklapse-bridge-'))throw Error('Unexpected temporary path');
  await fs.rm(resolved,{recursive:true,force:true});
 }
})().catch(e=>{console.error(e);process.exitCode=1});
