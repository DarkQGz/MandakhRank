// Offline tests only: no emails are sent.
const vm = require('node:vm');
const fs = require('node:fs');
const assert = require('node:assert/strict');
let props = {MAILER_SECRET:'a'.repeat(64)}, sends = [], quota = 100;
const context = {
  ContentService: {MimeType:{JSON:'json'}, createTextOutput:(v)=>({setMimeType:()=>JSON.parse(v)})},
  PropertiesService:{getScriptProperties:()=>({getProperty:(k)=>props[k],setProperties:(p)=>Object.assign(props,p)})},
  LockService:{getScriptLock:()=>({tryLock:()=>true,hasLock:()=>true,releaseLock:()=>{}})},
  MailApp:{getRemainingDailyQuota:()=>quota,sendEmail:(m)=>sends.push(m)},
};
vm.createContext(context);vm.runInContext(fs.readFileSync(__dirname+'/Code.gs','utf8'),context);
const post=(changes={})=>context.doPost({postData:{contents:JSON.stringify({secret:props.MAILER_SECRET,to:'person@example.com',code:'0007',...changes})}});
assert.equal(post({secret:'bad'}).ok,false);
assert.equal(post({to:'a@example.com,b@example.com'}).ok,false);
assert.equal(post({code:'hello'}).ok,false);
assert.equal(sends.length,0);
assert.equal(post().ok,true);
assert.ok(sends[0].body.includes('0007'));
quota=0;assert.equal(post().ok,false);quota=100;
for(let i=0;i<9;i++)assert.equal(post().ok,true);
assert.equal(post().ok,false);
assert.equal(sends.length,10);
assert.equal(context.doGet().ok,false);
console.log('Mailer validation, secret, recipient, quota and rate-limit checks passed.');
