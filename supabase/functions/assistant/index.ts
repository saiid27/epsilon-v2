// "مساعد إبسيلون" - tutoring assistant for subscribed students. Reads photos
// of exercises and solves them step by step.
//
// Secrets (Supabase dashboard → Edge Functions → Secrets):
//   ANTHROPIC_API_KEY   Claude API key (console.anthropic.com)
// Deploy: supabase functions deploy assistant
import Anthropic from 'npm:@anthropic-ai/sdk';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Per subscribed student and day. The free plan (live sessions and PDF
// files) has no assistant.
const DAILY_QUESTIONS = 10;
const DAILY_IMAGES = 6;
const MAX_HISTORY = 20;
// Base64 length of the largest photo accepted (~5 MB once decoded).
const MAX_IMAGE_CHARS = 7_000_000;
const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'] as const;
type ImageType = typeof IMAGE_TYPES[number];

const anthropic = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY') });

const SYSTEM_PROMPT = `أنت "مساعد إبسيلون"، مساعد تعليمي لطلاب الجامعة في موريتانيا على منصة Epsilon Education (رياضيات، فيزياء، كيمياء، إعلاميات...).
- أجب بالعربية الفصحى المبسطة، واترك المصطلحات العلمية بالفرنسية كما يدرسها الطالب. إذا كتب الطالب بالفرنسية فأجب بالفرنسية.
- عند حل تمرين: اكتب الحل في خطوات مرقمة، ثم النتيجة النهائية بوضوح، ثم تحقق سريع من النتيجة.
- اكتب المعادلات بصيغة نصية واضحة على سطر مستقل (مثل: ∫ x² dx = x³/3 + C).
- إذا أرسل الطالب صورة: اقرأ نص التمرين منها أولاً واكتبه باختصار، ثم حلّه. إذا كانت الصورة غير واضحة أو ناقصة فاطلب صورة أوضح بدل التخمين.
- إذا لم تكن متأكداً من خطوة فقل ذلك صراحة.
- عن الاشتراك: يختار الطالب القسم ثم المواد، ثم يحوّل المبلغ عبر Bankily أو مصرفي أو السداد ويرفع صورة الوصل، وتراجع الإدارة الطلب.
- اجعل الإجابات مناسبة لشاشة الهاتف.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const userId = String(body.userId ?? '').trim();
    const messages = Array.isArray(body.messages) ? body.messages : [];
    if (!userId) return json({ message: 'المستخدم غير معروف' }, 401);

    // Optional photo for the last question, as a data URI.
    const image = parseImage(body.image);
    if (body.image && !image) {
      return json({ message: 'الصورة غير صالحة أو كبيرة جداً.' }, 422);
    }

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
    if ((activeSubs ?? 0) === 0) {
      return json({ message: 'مساعد إبسيلون متاح للمشتركين فقط.' }, 403);
    }

    const today = new Date().toISOString().slice(0, 10);
    const { data: usage } = await supabase
      .from('assistant_usage')
      .select('questions, images')
      .eq('user_id', userId)
      .eq('day', today)
      .maybeSingle();
    const usedQuestions = usage?.questions ?? 0;
    const usedImages = usage?.images ?? 0;
    if (image && usedImages >= DAILY_IMAGES) {
      return json({ message: `وصلت إلى الحد اليومي للصور (${DAILY_IMAGES}).` }, 429);
    }
    if (!image && usedQuestions >= DAILY_QUESTIONS) {
      return json({ message: `وصلت إلى الحد اليومي للأسئلة (${DAILY_QUESTIONS}).` }, 429);
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

    // The photo goes with the last question, before its text.
    const last = history[history.length - 1];
    if (image && last.role === 'user') {
      last.content = [
        { type: 'image', source: { type: 'base64', media_type: image.type, data: image.data } },
        { type: 'text', text: String(last.content) },
      ];
    }

    const context = [
      body.subjectName ? `المادة الحالية: ${String(body.subjectName)}` : '',
      body.lessonTitle ? `الدرس الحالي: ${String(body.lessonTitle)}` : '',
    ].filter(Boolean).join('\n');

    const response = await anthropic.messages.create({
      model: 'claude-haiku-5-5',
      max_tokens: 16000,
      output_config: { effort: 'medium' },
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

    const questions = usedQuestions + (image ? 0 : 1);
    const images = usedImages + (image ? 1 : 0);
    await supabase.from('assistant_usage').upsert({
      user_id: userId,
      day: today,
      questions,
      images,
    });

    return json({
      reply: reply || 'لم أتمكن من صياغة إجابة، حاول إعادة صياغة سؤالك.',
      questionsLeft: Math.max(0, DAILY_QUESTIONS - questions),
      imagesLeft: Math.max(0, DAILY_IMAGES - images),
    });
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

function parseImage(value: unknown): { type: ImageType; data: string } | null {
  if (typeof value !== 'string' || value.length === 0) return null;
  const match = /^data:(image\/[a-z]+);base64,(.+)$/s.exec(value);
  if (!match) return null;
  const type = match[1] as ImageType;
  if (!IMAGE_TYPES.includes(type) || match[2].length > MAX_IMAGE_CHARS) return null;
  return { type, data: match[2] };
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
