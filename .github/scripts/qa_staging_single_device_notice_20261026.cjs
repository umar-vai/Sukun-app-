#!/usr/bin/env node
'use strict';
// Staging-only 90-minute synthetic fixture. Never sends an FCM message.
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const fs=require('node:fs');
const zlib=require('node:zlib');
const base='https://qacklgqvxvjjzsimjoip.supabase.co';
const key='sb_publishable_V6ALSIa032kI_Ec2q-gpJg_vgpbtXK0';
async function request(endpoint,token,method='GET',value,mime='application/json'){
  const headers={apikey:key,Accept:'application/json','Content-Type':mime};
  if(token)headers.Authorization='Bearer '+token;
  if(method==='POST'||method==='PATCH')headers.Prefer='return=representation';
  return fetch(base+endpoint,{
    method,headers,body:Buffer.isBuffer(value)?value:value===undefined?undefined:JSON.stringify(value),
    redirect:'error',signal:AbortSignal.timeout(25000)
  });
}
async function result(r,expected){
  assert.equal(r.status,expected,'Staging operation returned HTTP '+r.status);
  return r.json();
}
function png(){
  const w=480,h=240,scan=Buffer.alloc(h*(1+w*3));
  for(let y=0;y<h;y++)for(let x=0;x<w;x++){
    const i=y*(1+w*3)+1+x*3,line=(y>158&&y<169)||(y>188&&y<197);
    scan[i]=line?230:15+Math.floor(18*(1-x/w));
    scan[i+1]=line?247:110+Math.floor(35*x/w);
    scan[i+2]=line?253:170+Math.floor(28*y/h);
  }
  function chunk(name,body){
    const type=Buffer.from(name,'ascii'),len=Buffer.alloc(4),crcBuf=Buffer.alloc(4);
    len.writeUInt32BE(body.length);
    let c=0xffffffff;
    for(const b of Buffer.concat([type,body])){
      c^=b;for(let j=0;j<8;j++)c=(c>>>1)^((c&1)?0xedb88320:0);
    }
    crcBuf.writeUInt32BE((c^0xffffffff)>>>0);
    return Buffer.concat([len,type,body,crcBuf]);
  }
  const ihdr=Buffer.alloc(13);
  ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=2;
  return Buffer.concat([
    Buffer.from([137,80,78,71,13,10,26,10]),
    chunk('IHDR',ihdr),chunk('IDAT',zlib.deflateSync(scan,{level:9})),
    chunk('IEND',Buffer.alloc(0))
  ]);
}
async function main(){
  assert.equal(process.env.GITHUB_REF,'refs/heads/qa/staging-single-device-rich-fixture-20261026');
  assert.equal(process.env.GITHUB_RUN_ATTEMPT,'1');
  const email=process.env.SUKUN_STAGE_ADMIN_EMAIL;
  const password=process.env.SUKUN_STAGE_ADMIN_PASSWORD;
  assert.ok(email?.includes('@')&&password,'Synthetic staging Admin Secrets are required');
  const auth=await result(await request('/auth/v1/token?grant_type=password',null,'POST',{email,password}),200);
  const token=auth.access_token,uid=auth.user?.id;
  assert.ok(token&&uid&&!auth.user?.is_anonymous,'Staging Auth invalid');
  const roles=await result(await request('/rest/v1/user_roles?select=role,user_id&user_id=eq.'+uid,token),200);
  assert.ok(roles.some(x=>x.user_id===uid&&x.role==='super_admin'),'Server-verified Admin role missing');
  const existing=await result(await request(
    '/rest/v1/universal_announcements?select=id&status=eq.published&title=like.SUKUN%20DEVICE%20QA%25',token),200);
  assert.equal(existing.length,0,'Another live device QA fixture already exists');
  const unique=randomUUID(),name='notices/device-qa-'+unique+'.png';
  const imageUrl=base+'/storage/v1/object/public/sukun-announcement-images/'+name;
  const title='SUKUN DEVICE QA '+unique.slice(0,8);
  const deadline=new Date(Date.now()+50*60*1000).toISOString();
  const expires=new Date(Date.now()+90*60*1000).toISOString();
  let id,uploaded=false,done=false;
  try{
    const artwork=png();
    assert.ok(artwork.length<900*1024);
    const upload=await request('/storage/v1/object/sukun-announcement-images/'+name,token,'POST',artwork,'image/png');
    assert.ok([200,201].includes(upload.status),'Synthetic image upload rejected');
    uploaded=true;
    const drafts=await result(await request(
      '/rest/v1/universal_announcements?select=id,status,image_path,countdown_ends_at',token,'POST',{
        title,body:'শুধু অনুমোদিত Android test device-এর জন্য নমুনা নোটিশ। কোনো রোগীর তথ্য নেই।',
        image_path:name,countdown_ends_at:deadline,expires_at:expires,status:'draft'
      }),201);
    id=drafts[0]?.id;
    assert.ok(id&&drafts[0].status==='draft');
    const hidden=await result(await request('/rest/v1/universal_announcements?select=id&id=eq.'+id),200);
    assert.equal(hidden.length,0,'Draft is not restricted for Guest');
    const pub=await result(await request(
      '/rest/v1/universal_announcements?id=eq.'+id+'&select=id,status',token,'PATCH',{status:'published'}),200);
    assert.equal(pub[0]?.status,'published','Publish failed');
    const guest=await result(await request(
      '/rest/v1/universal_announcements?select=id,image_path,countdown_ends_at&id=eq.'+id),200);
    assert.equal(guest.length,1,'Public Guest cannot see published fixture');
    const picture=await fetch(imageUrl,{redirect:'error'});
    assert.equal(picture.status,200,'Public image unavailable');
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,[
      '### Single-device synthetic staging notice (NO FCM send)',
      '- UUID: '+id,
      '- Image URL: '+imageUrl,
      '- Countdown UTC: '+deadline,
      '- Guest visibility expires UTC: '+expires,
      '- Title: '+title,
      '- FCM data type: universal_announcement',
      '- No topic, campaign, broadcast or patient data.',
      '- Archive/delete this synthetic fixture after single-device QA.'
    ].join('\n')+'\n');
    console.log('PASS: staging Admin Auth/RLS, sample image, Draft -> Published and Guest visibility.');
    console.log('Synthetic notice UUID: '+id);
    console.log('Expires UTC: '+expires);
    done=true;
  }finally{
    if(!done){
      if(id)await request('/rest/v1/universal_announcements?id=eq.'+id,token,'PATCH',{status:'archived'});
      if(uploaded)await request('/storage/v1/object/sukun-announcement-images',token,'DELETE',{prefixes:[name]});
    }
  }
}
main().catch(e=>{console.error('Synthetic staging fixture failure: '+String(e.message).replace(/[\r\n]/g,' '));process.exitCode=1;});
