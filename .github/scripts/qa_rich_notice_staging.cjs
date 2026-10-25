#!/usr/bin/env node
'use strict';
// Controlled staging-only role-authenticated public notice QA. No topic send.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright-core');

const base = 'https://qacklgqvxvjjzsimjoip.supabase.co';
const key = process.env.SUKUN_STAGE_PUBLISHABLE_KEY;
const email = process.env.SUKUN_STAGE_ADMIN_EMAIL;
const password = process.env.SUKUN_STAGE_ADMIN_PASSWORD;
let stage = 'preflight';
const ck = v => { stage = v; console.log('CHECK: ' + v); };
async function request(endpoint, token, method='GET', body, mime='application/json') {
  const headers = {apikey:key,Accept:'application/json','Content-Type':mime};
  if (token) headers.Authorization = 'Bearer ' + token;
  if (method === 'POST' || method === 'PATCH') headers.Prefer = 'return=representation';
  const result = await fetch(base + endpoint, {
    method, headers, body:Buffer.isBuffer(body)?body:body===undefined?undefined:JSON.stringify(body),
    signal:AbortSignal.timeout(25000), redirect:'error'
  });
  return result;
}
async function rows(response, expected) {
  assert.equal(response.status,expected,'Staging REST operation failed');
  return response.json();
}
function server(root) {
  return http.createServer((req,res)=>{
    const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    if(pathname.includes('..')){res.writeHead(403).end();return;}
    let p=path.join(root,pathname);
    if(!p.startsWith(root)){res.writeHead(403).end();return;}
    if(!fs.existsSync(p)||!fs.statSync(p).isFile())p=path.join(root,'index.html');
    const ext=path.extname(p).toLowerCase();
    const type={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json','.png':'image/png','.css':'text/css','.svg':'image/svg+xml','.ttf':'font/ttf','.woff2':'font/woff2'}[ext]||'application/octet-stream';
    res.writeHead(200,{'Content-Type':type,'Cache-Control':'no-store'});
    fs.createReadStream(p).pipe(res);
  });
}
async function main(){
  assert.equal(process.env.SUKUN_STAGE_ONLY,'STAGING_ONLY','Explicit synthetic staging confirmation required');
  assert.ok(key?.startsWith('sb_publishable_')&&email?.includes('@')&&password,
    'Synthetic staging Super Admin Actions secrets missing');
  const auth=await rows(await request('/auth/v1/token?grant_type=password',null,'POST',{email,password}),200);
  const token=auth.access_token,uid=auth.user?.id;
  assert.ok(token&&uid&&!auth.user.is_anonymous,'Synthetic Admin auth invalid');
  ck('staging server-authorized Super Admin identity');
  const role=await rows(await request('/rest/v1/user_roles?select=role,user_id&user_id=eq.'+uid,token),200);
  assert.ok(role.some(x=>x.user_id===uid&&x.role==='super_admin'),'Staging account lacks real Super Admin role');
  ck('Clean up stale synthetic QA artwork through authorized Storage API');
  const listed=await rows(await request(
    '/storage/v1/object/list/sukun-announcement-images',token,'POST',
    {prefix:'notices',limit:100,offset:0}
  ),200);
  for(const entry of listed){
    const found=String(entry.name||'');
    const full=found.startsWith('notices/')?found:'notices/'+found;
    if(!/^notices\\/qa-rich-[a-f0-9-]{36}\\.png$/i.test(full))continue;
    const deleted=await request(
      '/storage/v1/object/sukun-announcement-images/'+encodeURI(full),
      token,'DELETE'
    );
    assert.ok([200,204].includes(deleted.status),'Stale QA artwork cleanup denied');
  }
  const uuid=crypto.randomUUID(), name='notices/qa-rich-'+uuid+'.png';
  const title='SUKUN QA ONLY '+uuid.slice(0,8);
  const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+iXgAAAABJRU5ErkJggg==','base64');
  let uploaded=false,noticeId;
  try{
    ck('Super Admin public image upload (synthetic 1px PNG)');
    const upload=await request('/storage/v1/object/sukun-announcement-images/'+name,token,'POST',png,'image/png');
    assert.ok([200,201].includes(upload.status),'Staging image upload denied');
    uploaded=true;
    ck('Admin draft with image and countdown');
    const deadline=new Date(Date.now()+45*60*1000).toISOString();
    const draft=await rows(await request('/rest/v1/universal_announcements?select=id,image_path,countdown_ends_at,status',token,'POST',{
      title,body:'QA synthetic public note only; no patient information',
      image_path:name,countdown_ends_at:deadline,status:'draft'
    }),201);
    noticeId=draft[0]?.id;
    assert.ok(noticeId&&draft[0].image_path===name&&draft[0].status==='draft');
    ck('Guest must NOT read draft');
    const guestBefore=await rows(await request('/rest/v1/universal_announcements?select=id&id=eq.'+noticeId),200);
    assert.equal(guestBefore.length,0,'Draft leaked to anonymous visitor');
    ck('Super Admin publishes image and live countdown');
    const published=await rows(await request('/rest/v1/universal_announcements?id=eq.'+noticeId+'&select=id,image_path,countdown_ends_at,status',token,'PATCH',{status:'published'}),200);
    assert.equal(published[0]?.status,'published');
    assert.equal(published[0]?.image_path,name);
    assert.ok(Date.parse(published[0]?.countdown_ends_at)>Date.now()+10000);
    const guestAfter=await rows(await request('/rest/v1/universal_announcements?select=id,image_path,countdown_ends_at&id=eq.'+noticeId),200);
    assert.equal(guestAfter.length,1,'Published public notice missing to Guest');
    assert.equal(guestAfter[0].image_path,name);
    const photo=await fetch(base+'/storage/v1/object/public/sukun-announcement-images/'+name,{redirect:'error'});
    assert.equal(photo.status,200,'Image not publicly viewable');
    ck('Real staging Flutter Web Guest deep-link Chrome boot');
    const root=path.resolve('app/build/web');
    assert.ok(fs.existsSync(path.join(root,'index.html')),'Staging Flutter build missing');
    const site=server(root);
    await new Promise(resolve=>site.listen(0,'127.0.0.1',resolve));
    let browser;
    try{
      browser=await chromium.launch({channel:'chrome',headless:true,args:['--no-sandbox']});
      const page=await browser.newPage({viewport:{width:390,height:844}});
      let jsErrors=0;page.on('pageerror',()=>jsErrors++);
      const response=await page.goto('http://127.0.0.1:'+site.address().port+'/announcements/'+noticeId,{waitUntil:'domcontentloaded',timeout:60000});
      assert.ok(response?.ok());
      await page.waitForSelector('flutter-view',{timeout:65000});
      await page.waitForTimeout(1800);
      assert.equal(jsErrors,0,'Flutter Guest route runtime error');
    }finally{if(browser)await browser.close();await new Promise(r=>site.close(r));}
    console.log('PASS: staging Auth/RLS image+countdown publish and real Guest browser boot');
  }finally{
    if(noticeId){
      ck('Archive synthetic notice (Guest should no longer access it)');
      const archive=await request('/rest/v1/universal_announcements?id=eq.'+noticeId,token,'PATCH',{status:'archived'});
      assert.equal(archive.status,200,'Failed to archive QA notice');
      const gone=await rows(await request('/rest/v1/universal_announcements?select=id&id=eq.'+noticeId),200);
      assert.equal(gone.length,0,'QA notice remained visible to Guest');
    }
    if(uploaded){
      ck('Delete staging synthetic artwork');
      const remove=await request('/storage/v1/object/sukun-announcement-images/'+name,token,'DELETE');
      assert.ok([200,204].includes(remove.status),'QA storage artwork cleanup unavailable');
    }
  }
  console.log('PASS: no published test notice remains; no broadcast invoked');
}
main().catch(e=>{
  console.error('FAIL: staging rich notice QA at '+stage+'; '+String(e.message).replace(/[\r\n]/g,' '));
  process.exitCode=1;
});
