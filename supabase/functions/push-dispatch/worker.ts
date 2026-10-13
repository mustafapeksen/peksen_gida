export type PushJob = { job_id: string; lease_id: string; notification_id: string; user_id: string; token: string };
export type Outcome = "sent" | "retry" | "invalid" | "failed";

// Stable notification ID makes retry replace an Android notification and open
// the same inbox item. FCM HTTP delivery itself is not exactly-once.
export function fcmMessage(job: PushJob) {
  return { message: {
    token: job.token,
    notification: { title: "Pekşen Gıda", body: "Yeni bir bildiriminiz var. Ayrıntıları uygulamada görüntüleyin." },
    data: { notification_id: job.notification_id, user_id: job.user_id },
    android: { ttl: "3600s", notification: { tag: job.notification_id } },
  } };
}
export function classify(status: number, payload: unknown): Outcome {
  if (status >= 200 && status < 300) return "sent";
  const details = (payload as {error?: {details?: {errorCode?: string}[]}})?.error?.details;
  if (details?.some((d) => d.errorCode === "UNREGISTERED")) return "invalid";
  if (status === 429 || status >= 500) return "retry";
  return "failed"; // auth/config/payload errors are not blindly retried
}
export async function dispatchBatch(
  jobs: PushJob[],
  send: (job: PushJob) => Promise<Outcome>,
  finish: (job: PushJob, outcome: Outcome) => Promise<void>,
): Promise<number> {
  // The bounded (25) batch must finish inside the database's two-minute lease.
  // Sequential 15-second HTTP timeouts could exceed it and duplicate sends.
  const results = await Promise.allSettled(jobs.map(async (job) => {
    let outcome: Outcome;
    try { outcome = await send(job); } catch { outcome = "retry"; }
    // If acknowledgement fails, lease expiry permits retry with the same ID.
    await finish(job, outcome);
  }));
  if (results.some(result => result.status === 'rejected')) throw new Error('Acknowledgement unavailable');
  return results.length;
}

export async function googleAccessToken(account: {client_email: string; private_key: string}, fetcher = fetch): Promise<string> {
  const encode = (value: string) => btoa(value).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  const now = Math.floor(Date.now() / 1000);
  const header = encode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = encode(JSON.stringify({ iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600 }));
  const pem = account.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const key = await crypto.subtle.importKey("pkcs8", Uint8Array.from(atob(pem), (x) => x.charCodeAt(0)),
    {name: "RSASSA-PKCS1-v1_5", hash: "SHA-256"}, false, ["sign"]);
  const bytes = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const assertion = `${header}.${claims}.${encode(String.fromCharCode(...new Uint8Array(bytes)))}`;
  const response = await fetcher("https://oauth2.googleapis.com/token", {method:"POST",
    headers:{"Content-Type":"application/x-www-form-urlencoded"},
    body:new URLSearchParams({grant_type:"urn:ietf:params:oauth:grant-type:jwt-bearer",assertion}),
    signal:AbortSignal.timeout(15000)});
  if(!response.ok) throw new Error("FCM authentication unavailable");
  const data=await response.json();
  if(typeof data.access_token!=="string") throw new Error("FCM authentication unavailable");
  return data.access_token;
}
