#!/usr/bin/env node
'use strict';
// Cleanup ONLY the completed single-device synthetic public notice via
// the real authenticated Admin Storage API. Never touch patient buckets.
const assert = require('node:assert/strict');
const base = 'https://qacklgqvxvjjzsimjoip.supabase.co';
const key = 'sb_publishable_V6ALSIa032kI_Ec2q-gpJg_vgpbtXK0';
const uuid = '09830085-d1f6-45ea-8ea8-888b9ee94b6a';
const path = 'notices/device-qa-fe355078-c39d-44ef-8f02-684a0c1414d6.png';
async function request(endpoint,token,method='GET',data){
  const headers={apikey:key,Accept:'application/json','Content-Type':'application/json'};
  if(token)headers.Authorization='Bearer '+token;
  if(method==='POST'||method==='PATCH')headers.Prefer='return=representation';
  return fetch(base+endpoint,{method,headers,body:data?JSON.stringify(data):undefined,redirect:'error',signal:AbortSignal.timeout(20000)});
}
async function read(result,expected){
 assert.equal(result.status,expected,'QA cleanup API status mismatch');
 return result.json();
}
async function main(){
 assert.equal(process.env.GITHUB_REF,'refs/heads/qa/staging-single-device-rich-fixture-20261026');
 assert.equal(process.env.GITHUB_RUN_ATTEMPT,'1');
 const email=process.env.SUKUN_STAGE_ADMIN_EMAIL,password=process.env.SUKUN_STAGE_ADMIN_PASSWORD;
 assert.ok(email?.includes('@')&&password,'Missing synthetic staging Admin credentials');
 const auth=await read(await request('/auth/v1/token?grant_type=password',null,'POST',{email,password}),200);
 assert.ok(auth.access_token&&auth.user?.id&&!auth.user?.is_anonymous);
 const token=auth.access_token;
 const roles=await read(await request('/rest/v1/user_roles?select=user_id,role&user_id=eq.'+auth.user.id,token),200);
 assert.ok(roles.some(x=>x.user_id===auth.user.id&&x.role==='super_admin'));
 const entries=await read(await request('/rest/v1/universal_announcements?select=id,title,image_path,status&id=eq.'+uuid,token),200);
 assert.equal(entries.length,1);
 const notice=entries[0];
 assert.ok(notice.title.startsWith('SUKUN DEVICE QA ') && notice.image_path===path);
 if(notice.status!=='archived'){
   const updated=await read(await request('/rest/v1/universal_announcements?id=eq.'+uuid+'&select=id,status',token,'PATCH',{status:'archived'}),200);
   assert.equal(updated[0]?.status,'archived');
 }
 const guest=await read(await request('/rest/v1/universal_announcements?select=id&id=eq.'+uuid),200);
 assert.equal(guest.length,0,'Archived test notice unexpectedly Guest-visible');
 const removed=await request('/storage/v1/object/sukun-announcement-images',token,'DELETE',{prefixes:[path]});
 assert.equal(removed.status,200,'Storage API refused only-synthetic artwork delete');
 console.log('PASS: archived exactly one synthetic notice; Guest cannot access; Storage API image removed.');
 console.log('No FCM send, no topic broadcast, no patient objects modified.');
}
main().catch(e=>{console.error('Staging synthetic cleanup failed: '+String(e.message).replace(/[\r\n]/g,' '));process.exitCode=1;});
