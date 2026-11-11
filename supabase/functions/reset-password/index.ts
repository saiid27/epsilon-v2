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
    const phone = String(body.phone ?? '').trim();
    const code = String(body.code ?? '').trim();
    const password = String(body.password ?? '');
    if (!phone || !code || password.length < 6) {
      return json({ message: 'البيانات غير مكتملة' }, 422);
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: otp } = await supabase
      .from('otp_codes')
      .select()
      .eq('phone', phone)
      .eq('purpose', 'password_reset')
      .single();
    if (!otp || otp.code !== code || new Date(otp.expires_at).getTime() < Date.now()) {
      return json({ message: 'رمز التحقق غير صالح' }, 422);
    }

    const { data: user } = await supabase
      .from('users')
      .select('id, status')
      .eq('phone', phone)
      .single();
    if (!user) return json({ message: 'رقم الهاتف غير مسجل.' }, 404);
    if (user.status !== 'active') {
      return json(
        { message: 'لا يمكن تغيير كلمة المرور إلا للحسابات المقبولة من الإدارة.' },
        403,
      );
    }

    const { error: updateError } = await supabase
      .from('users')
      .update({ password })
      .eq('id', user.id);
    if (updateError) {
      return json({ message: updateError.message }, 400);
    }

    await supabase
      .from('otp_codes')
      .delete()
      .eq('phone', phone)
      .eq('purpose', 'password_reset');
    return json({ message: 'تم تحديث كلمة المرور' });
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
