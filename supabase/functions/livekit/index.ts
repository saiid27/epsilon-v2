// Live classes on LiveKit: access tokens and start/end of a broadcast.
// Sessions are not recorded.
//
// Secrets (Supabase dashboard → Edge Functions → Secrets):
//   LIVEKIT_URL         wss://<project>.livekit.cloud
//   LIVEKIT_API_KEY     LiveKit API key
//   LIVEKIT_API_SECRET  LiveKit API secret
// Deploy: supabase functions deploy livekit --no-verify-jwt
import { SignJWT } from 'npm:jose@5';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const env = (name: string) => (Deno.env.get(name) ?? '').trim();

const supabase = createClient(
  env('SUPABASE_URL'),
  env('SUPABASE_SERVICE_ROLE_KEY'),
);

type Session = {
  id: string;
  subject_id: string | null;
  teacher_id: string | null;
  title: string;
  is_free: boolean;
  is_live: boolean;
  room_name: string;
  attendees_count: number;
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!env('LIVEKIT_URL') || !env('LIVEKIT_API_KEY') || !env('LIVEKIT_API_SECRET')) {
      return json({ message: 'البث المباشر غير مفعل بعد. أضف مفاتيح LiveKit.' }, 503);
    }

    const body = await req.json();
    const action = String(body.action ?? 'token');
    const userId = String(body.userId ?? '').trim();
    const sessionId = String(body.sessionId ?? '').trim();
    if (!userId) return json({ message: 'المستخدم غير معروف' }, 401);
    if (!sessionId) return json({ message: 'الجلسة غير معروفة' }, 400);

    const { data: user } = await supabase
      .from('users')
      .select('id, name, role, status')
      .eq('id', userId)
      .maybeSingle();
    if (!user || user.status !== 'active') {
      return json({ message: 'الحساب غير مفعل' }, 403);
    }

    const { data: session } = await supabase
      .from('live_sessions')
      .select('id, subject_id, teacher_id, title, is_free, is_live, room_name, attendees_count')
      .eq('id', sessionId)
      .maybeSingle<Session>();
    if (!session) return json({ message: 'الجلسة غير موجودة' }, 404);

    const isAdmin = user.role === 'admin' || user.role === 'developer';
    const isHost = isAdmin ||
      (user.role === 'teacher' && (!session.teacher_id || session.teacher_id === user.id));
    const room = session.room_name || `epsilon-${session.id}`;

    if (action === 'token') {
      if (!isHost && !(await canWatch(user.id, session))) {
        return json({ message: 'اشترك في المادة لحضور هذه الجلسة' }, 403);
      }
      return json({
        url: env('LIVEKIT_URL'),
        token: await accessToken(user.id, user.name, room, isHost),
        canPublish: isHost,
        isLive: session.is_live,
      });
    }

    if (!isHost) return json({ message: 'هذه العملية للأستاذ فقط' }, 403);

    if (action === 'start') {
      const token = await accessToken(user.id, user.name, room, true);
      const update: Record<string, unknown> = {
        is_live: true,
        room_name: room,
        started_at: new Date().toISOString(),
        ended_at: null,
      };
      await supabase.from('live_sessions').update(update).eq('id', session.id);
      if (!session.is_live) await notifyStudents(session);
      return json({ url: env('LIVEKIT_URL'), token, canPublish: true });
    }

    if (action === 'end') {
      const peak = Number(body.peakViewers ?? 0);
      await supabase.from('live_sessions').update({
        is_live: false,
        ended_at: new Date().toISOString(),
        attendees_count: Math.max(session.attendees_count ?? 0, Number.isFinite(peak) ? peak : 0),
      }).eq('id', session.id);
      try {
        await twirp('RoomService/DeleteRoom', { room }, { roomCreate: true });
      } catch (_) {
        // Room already closed.
      }
      return json({ ended: true });
    }

    return json({ message: 'عملية غير معروفة' }, 400);
  } catch (error) {
    console.error(error);
    return json({ message: 'تعذر الاتصال بخدمة البث، حاول مرة أخرى' }, 500);
  }
});

async function canWatch(userId: string, session: Session) {
  if (session.is_free) return true;
  if (!session.subject_id) return false;
  const { data } = await supabase
    .from('subject_subscriptions')
    .select('id, expires_at')
    .eq('student_id', userId)
    .eq('subject_id', session.subject_id)
    .eq('status', 'active');
  const now = Date.now();
  return (data ?? []).some((s: { expires_at: string | null }) =>
    !s.expires_at || new Date(s.expires_at).getTime() > now);
}

/// Tells subscribers of the subject, and everyone who asked for a reminder,
/// that the session has started.
async function notifyStudents(session: Session) {
  const ids = new Set<string>();
  const { data: reminders } = await supabase
    .from('live_reminders')
    .select('user_id')
    .eq('session_id', session.id);
  for (const r of reminders ?? []) ids.add(r.user_id);
  if (session.subject_id) {
    const { data: subs } = await supabase
      .from('subject_subscriptions')
      .select('student_id')
      .eq('subject_id', session.subject_id)
      .eq('status', 'active');
    for (const s of subs ?? []) ids.add(s.student_id);
  }
  if (ids.size === 0) return;
  await supabase.from('notifications').insert(
    [...ids].map((id) => ({
      user_id: id,
      kind: 'live',
      title: 'بدأ البث المباشر',
      body: `${session.title} • انضم الآن من تبويب مباشر`,
    })),
  );
  // The same message as a push notification on the phones.
  await sendPush([...ids], 'بدأ البث المباشر', session.title);
}

// Asks the push function to notify these users' phones. A failed push never
// stops the live session.
async function sendPush(userIds: string[], title: string, body: string) {
  try {
    await fetch(`${env('SUPABASE_URL')}/functions/v1/push`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-push-secret': env('PUSH_SECRET'),
        authorization: `Bearer ${env('SUPABASE_SERVICE_ROLE_KEY')}`,
      },
      body: JSON.stringify({ user_ids: userIds, title, body }),
    });
  } catch (_) {
    // Ignored on purpose.
  }
}

async function accessToken(identity: string, name: string, room: string, host: boolean) {
  return await sign({
    sub: identity,
    name,
    metadata: JSON.stringify({ host }),
    video: {
      room,
      roomJoin: true,
      canSubscribe: true,
      canPublish: host,
      canPublishData: true,
      roomAdmin: host,
    },
  }, 4 * 60 * 60);
}

async function sign(claims: Record<string, unknown>, ttlSeconds: number) {
  const secret = new TextEncoder().encode(env('LIVEKIT_API_SECRET'));
  const now = Math.floor(Date.now() / 1000);
  return await new SignJWT(claims)
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setIssuer(env('LIVEKIT_API_KEY'))
    .setNotBefore(now - 10)
    .setIssuedAt(now)
    .setExpirationTime(now + ttlSeconds)
    .sign(secret);
}

/// Calls the LiveKit server API (Twirp over HTTPS).
async function twirp(method: string, payload: unknown, grant: Record<string, unknown>) {
  const host = env('LIVEKIT_URL').replace(/^ws/, 'http').replace(/\/$/, '');
  const token = await sign({ video: grant }, 10 * 60);
  const res = await fetch(`${host}/twirp/livekit.${method}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`LiveKit ${method} ${res.status}: ${text}`);
  return text ? JSON.parse(text) : {};
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
