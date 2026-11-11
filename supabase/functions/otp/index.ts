import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const action = String(body.action ?? '');
    const phone = String(body.phone ?? '').trim();
    const purpose = String(body.purpose ?? 'auth');
    if (!phone) return json({ message: 'رقم الهاتف مطلوب' }, 422);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    if (action === 'request') {
      const { data: user } = await supabase
        .from('users')
        .select('id, status')
        .eq('phone', phone)
        .maybeSingle();

      if (!user) return json({ message: 'رقم الهاتف غير مسجل.' }, 404);
      if (user.status !== 'active') {
        return json(
          { message: 'لا يمكن إرسال الرمز إلا للحسابات المقبولة من الإدارة.' },
          403,
        );
      }

      const code = `${Math.floor(100000 + Math.random() * 900000)}`;
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();
      await supabase.from('otp_codes').upsert({
        phone,
        code,
        purpose,
        requested_at: new Date().toISOString(),
        expires_at: expiresAt,
      });

      const validationKey = Deno.env.get('CHINGUISOFT_VALIDATION_KEY');
      const validationToken = Deno.env.get('CHINGUISOFT_VALIDATION_TOKEN');
      if (validationKey && validationToken) {
        const response = await fetch(
          `https://chinguisoft.com/api/sms/validation/${validationKey}`,
          {
            method: 'POST',
            headers: {
              'Validation-token': validationToken,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              phone,
              lang: body.lang ?? 'ar',
              code,
            }),
          },
        );

        if (!response.ok) {
          await supabase
            .from('otp_codes')
            .delete()
            .eq('phone', phone)
            .eq('purpose', purpose);
          return json(
            { message: 'تعذر إرسال رمز التحقق. يرجى المحاولة لاحقًا.' },
            502,
          );
        }
      }

      return json({ message: 'تم إرسال رمز التحقق' });
    }

    if (action === 'verify') {
      const code = String(body.code ?? '').trim();
      const { data } = await supabase
        .from('otp_codes')
        .select()
        .eq('phone', phone)
        .eq('purpose', purpose)
        .single();
      if (!data || data.code !== code || new Date(data.expires_at).getTime() < Date.now()) {
        return json({ message: 'رمز التحقق غير صالح' }, 422);
      }
      if (purpose !== 'password_reset') {
        await supabase.from('otp_codes').delete().eq('phone', phone).eq('purpose', purpose);
      }
      return json({ message: 'تم التحقق من الرمز' });
    }

    return json({ message: 'Action invalide' }, 400);
  } catch (error) {
    return json({ message: error instanceof Error ? error.message : 'Erreur' }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
