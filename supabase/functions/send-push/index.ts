// send-push — Supabase Edge Function (Deno, zero dependencies).
// Two callers:
//   1) Partner updates: pg_net triggers in m13 post
//      { table, space_id, actor_id, title, body } on every partner-visible
//      insert (notes / piles / date_plans). Fans out to the partner's
//      devices only.
//   2) App updates: the GitHub release workflow posts
//      { type: "app_update", tag, url, notes } after a tag build is
//      published. Fans out to EVERY registered device.
// Auth: x-push-secret header must equal the PUSH_WEBHOOK_SECRET secret.
// Env (Dashboard > Edge Functions > Secrets, never committed):
//   FIREBASE_SERVICE_ACCOUNT_JSON, PUSH_WEBHOOK_SECRET
// Provided automatically by the platform:
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const PUSH_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const SA_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";

const KIND_FOR_TABLE: Record<string, string> = {
  notes: "note",
  piles: "pile",
  date_plans: "date",
};

function b64url(input: string | Uint8Array): string {
  const bytes =
    typeof input === "string" ? new TextEncoder().encode(input) : input;
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

// Mint a short-lived Google OAuth2 token from the service-account key.
// Cached in memory until near expiry (function instances are reused).
let cached: { token: string; projectId: string; exp: number } | null = null;
async function fcmAuth(): Promise<{ token: string; projectId: string }> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.exp - 60 > now) return cached;
  const sa = JSON.parse(SA_JSON) as {
    project_id: string;
    client_email: string;
    private_key: string;
  };
  const unsigned =
    b64url(JSON.stringify({ alg: "RS256", typ: "JWT" })) +
    "." +
    b64url(
      JSON.stringify({
        iss: sa.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }),
    );
  const pem = sa.private_key
    .replace(/-----[^-]+-----/g, "")
    .replace(/\s+/g, "");
  const raw = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    raw,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = unsigned + "." + b64url(new Uint8Array(sig));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) throw new Error("token exchange failed: " + res.status);
  const j = (await res.json()) as { access_token: string };
  cached = { token: j.access_token, projectId: sa.project_id, exp: now + 3600 };
  return cached;
}

async function rest(
  path: string,
): Promise<{ ok: boolean; status: number; json: unknown }> {
  const res = await fetch(SUPABASE_URL + "/rest/v1/" + path, {
    headers: {
      apikey: SERVICE_ROLE,
      Authorization: "Bearer " + SERVICE_ROLE,
    },
  });
  let json: unknown = null;
  try {
    json = await res.json();
  } catch {
    json = null;
  }
  return { ok: res.ok, status: res.status, json };
}

// Shared FCM fan-out: sends one notification to every token, collects
// dead (uninstalled) tokens so callers can sweep them. Never throws
// for transient per-token failures — they are simply unsent.
async function dispatch(
  tokens: string[],
  title: string,
  bodyText: string,
  data: Record<string, string>,
): Promise<{ sent: number; dead: string[] }> {
  const { token, projectId } = await fcmAuth();
  let sent = 0;
  const dead: string[] = [];
  for (const t of tokens) {
    const res = await fetch(
      "https://fcm.googleapis.com/v1/projects/" +
        projectId +
        "/messages:send",
      {
        method: "POST",
        headers: {
          Authorization: "Bearer " + token,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: t,
            notification: { title, body: bodyText },
            android: {
              priority: "high",
              notification: { channel_id: "ourspace_push" },
            },
            data,
          },
        }),
      },
    );
    if (res.ok) {
      sent++;
    } else {
      try {
        const err = (await res.json()) as {
          error?: { status?: string };
        };
        if (err?.error?.status === "NOT_FOUND") dead.push(t);
      } catch {
        // Leave the token; transient failure.
      }
    }
  }
  return { sent, dead };
}

async function sweepDead(dead: string[]): Promise<void> {
  // Drop tokens FCM no longer knows (app uninstalled): keeps the table
  // clean so future sends don't pay for dead rows.
  for (const d of dead) {
    await fetch(
      SUPABASE_URL +
        "/rest/v1/device_tokens?token=eq." +
        encodeURIComponent(d),
      {
        method: "DELETE",
        headers: {
          apikey: SERVICE_ROLE,
          Authorization: "Bearer " + SERVICE_ROLE,
        },
      },
    );
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  if (!PUSH_SECRET || req.headers.get("x-push-secret") !== PUSH_SECRET) {
    return new Response("unauthorized", { status: 401 });
  }
  let body: {
    type?: string;
    table?: string;
    space_id?: string;
    actor_id?: string;
    title?: string;
    body?: string;
    tag?: string;
    url?: string;
    notes?: string;
  };
  try {
    body = (await req.json()) as typeof body;
  } catch {
    return new Response("bad json", { status: 400 });
  }

  // Broadcast path: new app version released (called by the GitHub
  // release workflow, NOT by pg_net). Payload:
  //   { type: "app_update", tag: "v2.0.12",
  //     url: "https://github.com/o/r/releases/tag/v2.0.12",
  //     notes: "optional changelog" }
  // Fans out to EVERY registered device — no space/actor scoping.
  if (body.type === "app_update") {
    const tag = (body.tag ?? "").trim();
    if (!tag) return new Response("bad payload", { status: 400 });
    const url = (body.url ?? "").trim();
    const notes = (body.notes ?? body.body ?? "").trim();
    const toks = await rest("device_tokens?select=token&limit=1000");
    const raw = Array.isArray(toks.json)
      ? (toks.json as Array<{ token: string }>)
      : [];
    const tokens = [...new Set(raw.map((r) => r.token).filter(Boolean))];
    if (tokens.length === 0) {
      return Response.json({ ok: true, sent: 0, reason: "no-tokens" });
    }
    const title = "ourspace " + tag + " is here";
    const bodyText = notes
      ? notes.slice(0, 120)
      : "A cuter build is waiting — tap to update.";
    const { sent, dead } = await dispatch(tokens, title, bodyText, {
      kind: "update",
      tag,
      url,
    });
    await sweepDead(dead);
    return Response.json({ ok: true, sent, dead: dead.length, tag });
  }

  const kind = KIND_FOR_TABLE[body.table ?? ""];
  if (!kind || !body.space_id || !body.actor_id) {
    return new Response("bad payload", { status: 400 });
  }

  // Partners only: everyone in the space except the actor.
  const mem = await rest(
    "space_members?space_id=eq." +
      encodeURIComponent(body.space_id) +
      "&user_id=neq." +
      encodeURIComponent(body.actor_id) +
      "&select=user_id",
  );
  const partnerIds = Array.isArray(mem.json)
    ? (mem.json as Array<{ user_id: string }>).map((r) => r.user_id)
    : [];
  if (partnerIds.length === 0) {
    return Response.json({ ok: true, sent: 0, reason: "no-partners" });
  }

  const toks = await rest(
    "device_tokens?user_id=in.(" +
      partnerIds.map(encodeURIComponent).join(",") +
      ")&select=user_id,token",
  );
  const rows = Array.isArray(toks.json)
    ? (toks.json as Array<{ token: string }>)
    : [];
  const tokens = [...new Set(rows.map((r) => r.token).filter(Boolean))];
  if (tokens.length === 0) {
    return Response.json({ ok: true, sent: 0, reason: "no-tokens" });
  }

  // Friendly title: "<name> added a sweet note" when we know the name.
  let title = body.title || "Something sweet";
  try {
    const prof = await rest(
      "profiles?id=eq." +
        encodeURIComponent(body.actor_id) +
        "&select=username&limit=1",
    );
    const row = Array.isArray(prof.json)
      ? (prof.json as Array<{ username: string }>)[0]
      : undefined;
    const name = (row?.username ?? "").trim();
    if (name) title = name + ": " + title.charAt(0).toLowerCase() + title.slice(1);
  } catch {
    // Keep the plain title.
  }

  const { sent, dead } = await dispatch(
    tokens,
    title,
    body.body || "",
    { kind },
  );
  await sweepDead(dead);

  return Response.json({ ok: true, sent, dead: dead.length });
});
