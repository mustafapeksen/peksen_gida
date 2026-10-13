import { classify, dispatchBatch, fcmMessage, googleAccessToken, type PushJob } from "./worker.ts";
// Invoke from a trusted server scheduler only. Never from a Flutter client.
Deno.serve(async (request: Request) => {
  const reply = (status:number, result:unknown) => new Response(JSON.stringify(result),{status,headers:{"Content-Type":"application/json"}});
  if(request.method!=="POST") return reply(405,{ok:false});
  const admin=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!admin || request.headers.get("Authorization")!==`Bearer ${admin}`) return reply(401,{ok:false});
  const base=Deno.env.get("SUPABASE_URL")!;
  const rpc=async(name:string,data:unknown={})=>{
    const response=await fetch(`${base}/rest/v1/rpc/${name}`,{method:"POST",
      headers:{apikey:admin,Authorization:`Bearer ${admin}`,"Content-Type":"application/json"},body:JSON.stringify(data),signal:AbortSignal.timeout(15000)});
    if(!response.ok) throw new Error("Notification worker RPC unavailable");
    return await response.json();
  };
  try {
    const collected=await rpc("collect_notifications");
    const raw=Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if(!raw) return reply(200,{ok:true,collected,push:"not_configured"});
    const account=JSON.parse(raw);
    if(!/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(account.project_id) ||
      typeof account.client_email!=="string" || typeof account.private_key!=="string") return reply(503,{ok:false});
    const access=await googleAccessToken(account);
    const jobs:PushJob[]=await rpc("claim_push_jobs",{batch_size:25});
    const finished=await dispatchBatch(jobs,async(job)=>{
      const sent=await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,{
        method:"POST",headers:{Authorization:`Bearer ${access}`,"Content-Type":"application/json"},body:JSON.stringify(fcmMessage(job)),signal:AbortSignal.timeout(15000)});
      let data:unknown=null;
      try {data=await sent.json();} catch { /* No response details are logged. */ }
      return classify(sent.status,data);
    },async(job,outcome)=>{await rpc("finish_push_job",{job:job.job_id,lease:job.lease_id,outcome});});
    return reply(200,{ok:true,collected,finished});
  } catch { return reply(503,{ok:false}); }
});
