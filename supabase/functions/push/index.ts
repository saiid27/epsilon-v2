// Sends push notifications through Firebase Cloud Messaging (HTTP v1).
// Called only by other server functions, with the shared secret PUSH_SECRET.
//
// Secrets: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (provided by Supabase),
// PUSH_SECRET (any long random text), and FIREBASE_SERVICE_ACCOUNT (the JSON of
// the Firebase service account, as one line).
import { SignJWT, importPKCS8 } from 'npm:jose@5';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const env = (name: string) => (Deno.env.get(name) ?? '').trim();

type ServiceAccount = { client_email: string; private_key: string; project_id: string };

async function googleAccessToken(sa: ServiceAccount): Promise<string> {
  const key = await importPKCS8(sa.private_key, 'RS256');
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256' })
    .setIssuer(sa.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const json = await res.json();
  if (!res.ok) throw new Error('google token: ' + JSON.stringify(json));
  return json.access_token as string;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 });
  const secret = env('PUSH_SECRET');
  if (!secret || req.headers.get('x-push-secret') !== secret) {
    return new Response('forbidden', { status: 403 });
  }
  try {
    const body = await req.json();
    const ids: string[] = Array.isArray(body.user_ids) ? body.user_ids : [];
    const title = String(body.title ?? '');
    const text = String(body.body ?? '');
    if (ids.length === 0 || !title) {
      return Response.json({ sent: 0, failed: 0 });
    }

    const supabase = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'));
    const { data: rows, error } = await supabase
      .from('users')
      .select('push_token')
      .in('id', ids)
      .neq('push_token', '');
    if (error) throw error;
    const tokens = [...new Set((rows ?? []).map((r) => r.push_token as string))].filter(Boolean);
    if (tokens.length === 0) return Response.json({ sent: 0, failed: 0 });

    const sa: ServiceAccount = JSON.parse(env('FIREBASE_SERVICE_ACCOUNT'));
    const access = await googleAccessToken(sa);
    const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

    let sent = 0;
    let failed = 0;
    for (const token of tokens) {
      const res = await fetch(url, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${access}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body: text },
            android: { priority: 'high' },
          },
        }),
      });
      if (res.ok) sent++;
      else failed++;
    }
    return Response.json({ sent, failed });
  } catch (e) {
    return new Response(`push failed: ${e}`, { status: 500 });
  }
});
