// Runtime-managed server credential never leaves this function or enters Flutter.
const headers = { "Content-Type": "application/json" };
const reply = (status: number) => new Response(JSON.stringify({ ok: status === 200 }), { status, headers });
Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return reply(405);
  const authorization = request.headers.get("Authorization") ?? "";
  const base = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const admin = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  let invitationId: string | null = null;
  const rpc = (name: string, body: unknown) => fetch(`${base}/rest/v1/rpc/${name}`, {
    method: "POST", headers: { ...headers, apikey: anon, Authorization: authorization }, body: JSON.stringify(body),
  });
  try {
    // Gateway verification is disabled for key compatibility; Auth validates the
    // actual bearer token here. Caller roles/authority are then checked by SQL.
    const user = await fetch(`${base}/auth/v1/user`, { headers: { apikey: anon, Authorization: authorization } });
    if (!user.ok) return reply(401);
    const body = await request.json();
    const prepared = await rpc("create_account_invitation", {
      invitee_email: body.email, display_name: body.name,
      target_role: body.role, target_customer: body.customer_id ?? null,
    });
    if (!prepared.ok) return reply(403);
    invitationId = await prepared.json();
    const sent = await fetch(`${base}/auth/v1/invite`, {
      method: "POST", headers: { ...headers, apikey: admin, Authorization: `Bearer ${admin}` },
      body: JSON.stringify({ email: String(body.email).trim().toLowerCase() }),
    });
    if (!sent.ok) {
      await rpc("revoke_account_invitation", { invitation_id: invitationId });
      return reply(400);
    }
    return reply(200);
  } catch (_) {
    if (invitationId) {
      try { await rpc("revoke_account_invitation", { invitation_id: invitationId }); } catch (_) { /* expires; no profile granted */ }
    }
    return reply(400);
  }
});
