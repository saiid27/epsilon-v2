// "مساعد إبسيلون" - tutoring assistant for students.
//
// Secrets (Supabase dashboard → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   Claude API key
// Deploy: supabase functions deploy assistant
import Anthropic from 'npm:@anthropic-ai/sdk';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Questions per day. Free accounts match the "5 أسئلة يومياً" in the app.
const FREE_DAILY_LIMIT = 5;
const SUBSCRIBED_DAILY_LIMIT = 50;
const MAX_HISTORY = 20;

const anthropic = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY') });

const SYSTEM_PROMPT = `أنت "مساعد إبسيلون"، مساعد تعليمي لطلاب الجامعة في موريتانيا على منصة Epsilon Education.
- أجب بالعربية الفصحى المبسطة، إلا إذا كتب الطالب بالفرنسية فأجب بالفرنسية.
- اشرح خطوة بخطوة بأمثلة قصيرة، واكتب المعادلات بصيغة نصية واضحة.
- عند حل تمرين، وجّه الطالب للفهم وقدّم الحل مرتباً في خطوات مرقمة.
- عن الاشتراك: يختار الطالب المادة من «استكشف المواد»، ثم الخطة، ثم يحوّل المبلغ عبر Bankily أو مصرفي أو السداد ويرفع صورة الوصل من شاشة «رفع وصل الدفع»، وتراجع الإدارة الطلب.
- اجعل الإجابات مختصرة ومناسبة لشاشة الهاتف.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const userId = String(body.userId ?? '').trim();
    const messages = Array.isArray(body.messages) ? body.messages : [];
    if (!userId) return json({ message: 'المستخدم غير معروف' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: user } = await supabase
      .from('users')
      .select('id, status')
      .eq('id', userId)
      .maybeSingle();
    if (!user || user.status !== 'active') {
      return json({ message: 'الحساب غير مفعل' }, 403);
    }

    const { count: activeSubs } = await supabase
      .from('subject_subscriptions')
      .select('id', { count: 'exact', head: true })
      .eq('student_id', userId)
      .eq('status', 'active');
    const limit = (activeSubs ?? 0) > 0 ? SUBSCRIBED_DAILY_LIMIT : FREE_DAILY_LIMIT;

    const today = new Date().toISOString().slice(0, 10);
    const { data: usage } = await supabase
      .from('assistant_usage')
      .select('questions')
      .eq('user_id', userId)
      .eq('day', today)
      .maybeSingle();
    const used = usage?.questions ?? 0;
    if (used >= limit) {
      return json({ message: 'وصلت إلى الحد اليومي للأسئلة.' }, 429);
    }

    // Keep only well-formed turns, starting with a user turn.
    const history: Anthropic.MessageParam[] = messages
      .filter((m: { role?: string; content?: unknown }) =>
        (m.role === 'user' || m.role === 'assistant') &&
        typeof m.content === 'string' &&
        m.content.trim().length > 0)
      .slice(-MAX_HISTORY)
      .map((m: { role: 'user' | 'assistant'; content: string }) => ({
        role: m.role,
        content: m.content.slice(0, 4000),
      }));
    while (history.length > 0 && history[0].role !== 'user') history.shift();
    if (history.length === 0) return json({ message: 'اكتب سؤالك أولاً' }, 422);

    const context = [
      body.subjectName ? `المادة الحالية: ${String(body.subjectName)}` : '',
      body.lessonTitle ? `الدرس الحالي: ${String(body.lessonTitle)}` : '',
    ].filter(Boolean).join('\n');

    const response = await anthropic.beta.messages.create({
      model: 'claude-opus-5-5',
      max_tokens: 16000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low' },
      system: context ? `${SYSTEM_PROMPT}\n\n${context}` : SYSTEM_PROMPT,
      messages: history,
    });

    if (response.stop_reason === 'refusal') {
      return json({ reply: 'عذراً، لا أستطيع المساعدة في هذا الطلب. اسألني عن دروسك أو تمارينك.' });
    }

    const reply = response.content
      .filter((block) => block.type === 'text')
      .map((block) => (block as { text: string }).text)
      .join('\n')
      .trim();

    await supabase.from('assistant_usage').upsert({
      user_id: userId,
      day: today,
      questions: used + 1,
    });

    return json({ reply: reply || 'لم أتمكن من صياغة إجابة، حاول إعادة صياغة سؤالك.' });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      return json({ message: 'المساعد مشغول الآن، حاول بعد قليل.' }, 503);
    }
    if (error instanceof Anthropic.APIError) {
      return json({ message: 'تعذر الوصول إلى المساعد.' }, 502);
    }
    return json({ message: error instanceof Error ? error.message : 'Erreur' }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
