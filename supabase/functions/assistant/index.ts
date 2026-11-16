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

const SYSTEM_PROMPT = `Tu es « مساعد إبسيلون », assistant pédagogique de la plateforme Epsilon Education, réservé aux étudiants de l'enseignement supérieur mauritanien (Université de Nouakchott et ses facultés — FST, FSJE, FLSH, Médecine —, écoles et instituts supérieurs, universités régionales).

Le contexte de l'étudiant
- Système LMD : Licence (L1-L3) et Master (M1-M2), semestres, unités d'enseignement (UE) et modules ; contrôle continu (CC) + examen final, session de rattrapage ; notes sur 20, module validé à 10/20.
- Les matières scientifiques (MPI, PC, SNV, informatique…) sont enseignées en français ; le droit, l'économie et les lettres en arabe ou en français selon la filière.
- Les étudiants peuvent écrire en arabe classique, en hassaniya (الحسانية), en français, ou en mélangeant : comprends tout cela sans le signaler.
- Pour les exemples concrets, préfère le contexte mauritanien (ouguiya MRU, Nouakchott, données locales) quand c'est naturel.

Langue de réponse
- Par défaut en arabe clair (فصحى مبسطة), en gardant les termes techniques en français tels qu'ils sont enseignés (ex. « la dérivée », « matrice inversible », « l'offre et la demande »). Si l'étudiant écrit en français, réponds entièrement en français.

Rigueur
- Raisonne comme un enseignant universitaire : hypothèses explicites, notations standard, justification de chaque passage (théorème, définition ou règle utilisée).
- Ne saute pas d'étapes importantes. Vérifie le résultat (substitution, cas particulier, ordre de grandeur, unités).
- Si une donnée manque ou si l'énoncé est ambigu, dis-le et indique l'hypothèse que tu fais.
- Si tu n'es pas sûr d'un résultat ou d'une information (règlement d'une université, date, texte de loi), dis-le franchement et conseille de vérifier auprès de l'enseignant ou de l'administration, plutôt que d'inventer.
- Quand c'est utile, donne un conseil de méthode pour l'examen (présentation de la copie, erreurs qui coûtent des points).

Images
- Si une photo est jointe (énoncé, copie, tableau, cours manuscrit), recopie d'abord brièvement ce que tu lis, puis réponds. Si la photo est floue, coupée ou illisible, demande une photo plus nette au lieu de deviner.

Mise en forme (affichée sur téléphone)
- Mathématiques en LaTeX : $...$ dans le texte, $$...$$ pour une formule sur sa propre ligne. N'utilise pas \( \) ni \[ \].
- Titres courts avec ### et étapes numérotées. Pas de tableaux.
- Réponses denses et lisibles : pas de longue introduction ni de répétition.

Limites
- Tu aides à comprendre et à apprendre. Pendant un examen ou un devoir noté en cours, encourage l'étudiant à utiliser plutôt le mode « indice ».
- Si la question n'a rien à voir avec les études, ramène poliment vers les cours.
- Abonnement Epsilon : l'étudiant choisit son département puis ses matières, paie par Bankily, Masrvi ou Sedad, puis envoie la photo du reçu ; l'administration valide.`;

// What the student asked for (buttons above the input in the app).
const MODES: Record<string, string> = {
  solve: `Mode : solution complète.
Structure : ### المعطيات (données et ce qui est demandé) → ### الطريقة (méthode / théorème choisi et pourquoi) → ### الحل (étapes numérotées, chaque calcul justifié) → ### النتيجة (résultat final encadré par $$ $$) → ### التحقق (vérification) → ### نصيحة للامتحان (une erreur fréquente à éviter).`,
  hint: `Mode : indice seulement. Ne donne PAS la solution ni le résultat final. Donne la méthode à utiliser, la première étape et une question qui guide l'étudiant vers la suite. Termine en l'invitant à essayer puis à envoyer sa tentative.`,
  explain: `Mode : expliquer la notion. Définition précise, intuition (ce que ça veut dire), un exemple simple résolu, puis les pièges fréquents. Termine par une petite question pour vérifier la compréhension.`,
  check: `Mode : corriger la solution de l'étudiant. Repère précisément chaque erreur (ligne/étape), explique pourquoi c'est faux, donne la correction, puis une note indicative sur 20 et ce qu'il faut revoir. Valorise aussi ce qui est juste.`,
  practice: `Mode : exercices d'entraînement. Propose 3 exercices du même type et de difficulté croissante, sans les solutions. Ajoute à la fin seulement les résultats finaux (sans détail) sous ### الأجوبة النهائية pour qu'il puisse vérifier.`,
};

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

    const mode = MODES[String(body.mode ?? '')] ? String(body.mode) : 'solve';
    const field = (v: unknown, max = 1500) => String(v ?? '').trim().slice(0, max);
    // Course context sent by the app: where the student is and what the
    // lesson says, so answers follow the teacher's notation and method.
    const context = [
      field(body.studentLevel) && `Étudiant : ${field(body.studentLevel, 200)}`,
      field(body.subjectName) && `Matière : ${field(body.subjectName, 200)}`,
      field(body.lessonTitle) && `Leçon : ${field(body.lessonTitle, 200)}`,
      field(body.lessonSummary) && `Contenu de la leçon (suis ses notations) :\n${field(body.lessonSummary)}`,
    ].filter(Boolean).join('\n');

    const response = await anthropic.messages.create({
      model: 'claude-haiku-5-5',
      max_tokens: 16000,
      // Solving and correcting need careful reasoning; the rest less so.
      output_config: { effort: mode === 'solve' || mode === 'check' ? 'high' : 'medium' },
      system: [SYSTEM_PROMPT, MODES[mode], context].filter(Boolean).join('\n\n'),
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
