import { classify, dispatchBatch, fcmMessage, googleAccessToken, type PushJob } from "./worker.ts";
function assert(value:unknown) {if(!value) throw new Error("Assertion failed");}
const job:PushJob={job_id:"job",lease_id:"lease",notification_id:"notification",user_id:"user",token:"synthetic-device-token"};
Deno.test("Generic FCM payload and stable notification tag",()=>{
 const payload=fcmMessage(job);
 assert(payload.message.android.notification.tag===job.notification_id);
 assert(Object.keys(payload.message.data).sort().join(",")==="notification_id,user_id");
 assert(!JSON.stringify(payload).includes("latitude"));
});
Deno.test("Response classification never deletes tokens for generic validation errors",()=>{
 assert(classify(200,{})==="sent"); assert(classify(429,{})==="retry"); assert(classify(503,{})==="retry");
 assert(classify(400,{})==="failed"); assert(classify(401,{})==="failed");
 assert(classify(404,{error:{details:[{errorCode:"UNREGISTERED"}]}})==="invalid");
});
Deno.test("Transport failure retries same job; acknowledgement failure escapes",async()=>{
 const outcomes:string[]=[];
 assert(await dispatchBatch([job],()=>Promise.reject(new Error("offline")),async(j,result)=>{assert(j===job);outcomes.push(result);})===1);
 assert(outcomes[0]==="retry");
 let failed=false;
 try {await dispatchBatch([job],async()=>"sent",async()=>{throw new Error("lost ack");});} catch {failed=true;}
 assert(failed);
});
Deno.test("OAuth assertion is signed with ephemeral key and fixed Google audience",async()=>{
 const keys=await crypto.subtle.generateKey({name:"RSASSA-PKCS1-v1_5",modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:"SHA-256"},true,["sign","verify"]);
 const raw=await crypto.subtle.exportKey("pkcs8",keys.privateKey);
 const pem=`-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...new Uint8Array(raw)))}\n-----END PRIVATE KEY-----`;
 const token=await googleAccessToken({client_email:"synthetic@example.invalid",private_key:pem},async(url,options)=>{
  assert(url==="https://oauth2.googleapis.com/token");
  const parts=(options!.body as URLSearchParams).get("assertion")!.split(".");
  const decode=(value:string)=>Uint8Array.from(atob(value.replaceAll("-","+").replaceAll("_","/")),c=>c.charCodeAt(0));
  assert(await crypto.subtle.verify("RSASSA-PKCS1-v1_5",keys.publicKey,decode(parts[2]),new TextEncoder().encode(parts.slice(0,2).join("."))));
  const claims=JSON.parse(new TextDecoder().decode(decode(parts[1])));
  assert(claims.aud==="https://oauth2.googleapis.com/token"); assert(claims.exp-claims.iat===3600);
  return new Response(JSON.stringify({access_token:"synthetic-only"}));
 });
 assert(token==="synthetic-only");
});
