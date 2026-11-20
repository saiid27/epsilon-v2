// "مساعد إبسيلون" - assistant for subscribed students of Mauritanian higher
// education: solves and explains exercises, reads photos and PDF files,
// writes CVs, letters and reports (the app saves any answer as a PDF).
//
// Each student has a daily allowance of questions and files; what is not
// used carries over to the next days, up to CARRY_DAYS days' worth.
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

// Usage budget per student, in MRU (Mauritanian ouguiya) of model cost.
// Formula: daily cap = monthly budget / 30; the cost of an answer is
// (input tokens x input price + output tokens x output price) / 1 000 000 USD,
// converted to MRU with the rate below.
const MRU_PER_USD = 40;
type Tier = { monthlyMru: number };
const TIERS: Record<string, Tier> = {
  // Paid plans: the student gets about two thirds of the plan price as usage.
  basic: { monthlyMru: 100 },    // plan 150 MRU
  standard: { monthlyMru: 200 }, // plan 300 MRU
  pro: { monthlyMru: 300 },      // plan 450 MRU
  // Free plan: enough to try the assistant, a few answers a day.
  free: { monthlyMru: 3.6 },
};
const monthlyUsd = (t: Tier) => t.monthlyMru / MRU_PER_USD;
const dailyUsd = (t: Tier) => monthlyUsd(t) / 30;
// Models and prices (USD per million tokens). Sonnet is used for the modes
// that need careful reasoning on paid plans; everything else runs on Haiku.
const MODELS = {
  sonnet: { id: 'claude-sonnet-5-5', inPrice: 2.0, outPrice: 10.0 },
  haiku: { id: 'claude-haiku-5-5', inPrice: 0.1, outPrice: 0.5 },
} as const;
const SONNET_MODES = new Set(['solve', 'check', 'exam', 'explain']);
// Longest answer, in output tokens.
const MAX_ANSWER_TOKENS = 4000;
// Below this, a request is refused rather than run on a near-empty balance.
const MIN_LEFT_USD = 0.002;
// Files need room for their pages: about 20 000 input tokens on the model.
const FILE_INPUT_TOKENS = 20_000;
// Typical input of one question, used to keep the answer within the balance.
const ASSUMED_INPUT_TOKENS = 3_000;
const MAX_HISTORY = 20;
// Base64 length of the largest attachment accepted (~7.5 MB once decoded).
const MAX_FILE_CHARS = 10_000_000;
const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

// Trimmed: a stray space or newline pasted with the secret makes Claude return 401.
const anthropic = new Anthropic({ apiKey: (Deno.env.get('ANTHROPIC_API_KEY') ?? '').trim() });

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

Ce que tu fais pour l'étudiant
- Résoudre et expliquer les exercices et les cours, corriger ses copies, l'entraîner.
- Ses démarches d'étudiant : CV, lettre de motivation, demande de stage, e-mail à un enseignant, rapport ou mémoire (plan, rédaction, relecture), exposé. L'application peut enregistrer chacune de tes réponses en PDF : rédige-les donc propres et complètes, prêtes à être imprimées.

Photos et PDF
- Si une photo est jointe (énoncé, copie, tableau, cours manuscrit), recopie d'abord brièvement ce que tu lis, puis réponds. Si la photo est floue, coupée ou illisible, demande une photo plus nette au lieu de deviner.
- Si un PDF est joint (cours, TD, examen, article), base ta réponse sur son contenu et cite les pages ou sections utiles. Ne prétends pas avoir lu ce qui n'y est pas.

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
  cv: `Mode : CV. Construis le CV de l'étudiant pas à pas. S'il manque des informations, pose-lui au plus 5 questions courtes et précises (formation, stages, projets, compétences, langues, coordonnées) sans rien inventer. Quand tu as assez d'éléments, rédige le CV complet, en français par défaut (ou dans la langue demandée), adapté à un étudiant mauritanien qui cherche un stage ou un premier emploi : ### Nom et titre, coordonnées, ### Profil (2-3 lignes), ### Formation, ### Expériences et stages, ### Projets, ### Compétences, ### Langues, ### Centres d'intérêt. Phrases courtes, verbes d'action, dates au format MM/AAAA. Termine par une ligne : « اضغط "حفظ PDF" تحت هذه الرسالة لتنزيل سيرتك الذاتية ».`,
  write: `Mode : rédaction. Rédige le document demandé (lettre de motivation, demande de stage, demande administrative, e-mail à un enseignant, rapport, plan de mémoire, exposé) dans la langue et le registre attendus en Mauritanie (français administratif ou arabe soutenu). S'il manque des informations essentielles (destinataire, objet, dates), demande-les d'abord en une seule question. Produis un texte complet, prêt à imprimer, sans commentaires autour.`,
  fiche: `Mode : fiche de révision. À partir du cours (texte, PDF ou photo jointe), produis une fiche concise et prête à réviser : ### L'essentiel (3-5 idées clés), ### Définitions et théorèmes (énoncés exacts avec leurs conditions), ### Formules à retenir (en LaTeX, $$ $$), ### Méthode type (une démarche en étapes pour l'exercice classique), ### Pièges de l'examen (3 erreurs fréquentes). Reste dense : une page à imprimer.`,
  exam: `Mode : simulation d'examen. Si l'étudiant n'a pas encore précisé la matière et la durée, demande-les en une question. Sinon, propose un sujet d'examen blanc dans le style d'un examen de Licence mauritanienne : 4 à 5 questions de difficulté croissante, avec barème sur 20 indiqué pour chacune, et la durée conseillée. Ne donne AUCUNE correction. Quand l'étudiant envoie ses réponses, corrige-les comme un correcteur (points obtenus par question, note sur 20, commentaire d'ensemble).`,
  plan: `Mode : plan de révision. Demande d'abord (en une seule fois) : les matières et les dates des examens, le nombre d'heures disponibles par jour, et les points faibles déjà connus. Puis produis un planning jour par jour jusqu'à l'examen, avec pour chaque jour : matière, notion, durée, et une révision de contrôle les jours précédant chaque examen. Présente-le sous forme de liste par semaine, pas de tableau.`,
  french: `Mode : français académique. Si le texte est en français : corrige-le (orthographe, accords, registre académique) et explique brièvement chaque correction. Si l'étudiant demande une traduction ou le sens d'un terme : donne le terme français, sa traduction arabe et une phrase d'exemple tirée d'un contexte universitaire. Pour un cours, extrais le vocabulaire technique utile sous forme de glossaire.`,
  pfe: `Mode : mémoire ou projet de fin d'études (PFE). Aide l'étudiant pas à pas : problématique, plan détaillé (introduction, chapitres, conclusion), méthodologie, structure de la bibliographie (format standard), et relecture de ses paragraphes. Ne rédige jamais le mémoire à sa place : propose la structure et les paragraphes-types à compléter, et explique pourquoi chaque partie est là.`,
  code: `Mode : programmation. Explique le code joint ou le problème, puis indique l'erreur précisément (ligne et cause), donne la correction minimale, et termine par une façon de tester la solution. Langages courants à l'université : Python, C, Java, SQL, MATLAB. Mets le code dans des blocs de code.`,
  pdf: `Mode : commenter un PDF. Sur le document joint : ### ملخص (résumé fidèle en quelques points), ### الأفكار الأساسية (notions clés, définitions et formules importantes avec la page), ### شرح الأجزاء الصعبة, ### أسئلة امتحان محتملة (4-6 questions avec indications de réponse). Si l'étudiant pose une question précise sur le PDF, réponds plutôt directement à sa question.`,
};

type Attachment =
  | { kind: 'image'; type: 'image/png' | 'image/jpeg' | 'image/webp' | 'image/gif'; data: string }
  | { kind: 'pdf'; data: string; name: string };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const userId = String(body.userId ?? '').trim();
    if (!userId) return json({ message: 'المستخدم غير معروف' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: user } = await supabase
      .from('users')
      .select('id, status, assistant_tier')
      .eq('id', userId)
      .maybeSingle();
    if (!user || user.status !== 'active') {
      return json({ message: 'الحساب غير مفعل' }, 403);
    }

    // A bought assistant package wins. Otherwise a subject subscriber gets the
    // default tier, and everyone else gets the free plan.
    const { data: pkg } = await supabase
      .from('assistant_subscriptions')
      .select('tier')
      .eq('student_id', userId)
      .eq('status', 'active')
      .gt('expires_at', new Date().toISOString())
      .order('expires_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    const { count: activeSubs } = await supabase
      .from('subject_subscriptions')
      .select('id', { count: 'exact', head: true })
      .eq('student_id', userId)
      .eq('status', 'active');
    const tier = pkg && TIERS[pkg.tier]
      ? TIERS[pkg.tier]
      : (activeSubs ?? 0) > 0
        ? await tierFor(supabase, user.assistant_tier)
        : TIERS.free;
    const bonus = await seasonBonus(supabase);
    const budget = await remainingBudget(supabase, userId, tier, bonus);
    if (body.action === 'balance') {
      return json(percentLeft(budget, tier, bonus));
    }

    const attachment = parseAttachment(body.image, body.document, body.documentName);
    if ((body.image || body.document) && !attachment) {
      return json({ message: 'الملف غير صالح أو كبير جداً (الحد 7 ميغابايت).' }, 422);
    }
    const left = Math.min(budget.dailyUsd, budget.monthlyUsd);
    if (left < MIN_LEFT_USD) {
      return json({ message: 'نفد رصيدك من الاستعمال. يتجدد الرصيد اليومي غداً.' }, 429);
    }
    const fileLeftNeeded = (FILE_INPUT_TOKENS * MODELS.sonnet.inPrice) / 1_000_000;
    if (attachment && left < fileLeftNeeded) {
      return json({ message: 'رصيدك اليومي لا يكفي لقراءة هذا الملف. جرّب غداً أو ملفاً أصغر.' }, 429);
    }

    // Keep only well-formed turns, starting with a user turn.
    const messages = Array.isArray(body.messages) ? body.messages : [];
    const history: Anthropic.MessageParam[] = messages
      .filter((m: { role?: string; content?: unknown }) =>
        (m.role === 'user' || m.role === 'assistant') &&
        typeof m.content === 'string' &&
        m.content.trim().length > 0)
      .slice(-MAX_HISTORY)
      .map((m: { role: 'user' | 'assistant'; content: string }) => ({
        role: m.role,
        content: m.content.slice(0, 6000),
      }));
    while (history.length > 0 && history[0].role !== 'user') history.shift();
    if (history.length === 0) return json({ message: 'اكتب سؤالك أولاً' }, 422);

    // The attachment goes with the last question, before its text.
    const last = history[history.length - 1];
    if (attachment && last.role === 'user') {
      const text = { type: 'text' as const, text: String(last.content) };
      last.content = attachment.kind === 'image'
        ? [{ type: 'image', source: { type: 'base64', media_type: attachment.type, data: attachment.data } }, text]
        : [{
          type: 'document',
          source: { type: 'base64', media_type: 'application/pdf', data: attachment.data },
          title: attachment.name,
        }, text];
    }

    const mode = MODES[String(body.mode ?? '')] ? String(body.mode) : 'solve';
    const field = (v: unknown, max = 1500) => String(v ?? '').trim().slice(0, max);
    // Course context sent by the app: where the student is and what the
    // lesson says, so answers follow the teacher's notation and method.
    const context = [
      field(body.studentLevel) && `Étudiant : ${field(body.studentLevel, 200)}`,
      field(body.studentName) && `Nom de l'étudiant : ${field(body.studentName, 120)}`,
      field(body.subjectName) && `Matière : ${field(body.subjectName, 200)}`,
      field(body.lessonTitle) && `Leçon : ${field(body.lessonTitle, 200)}`,
      field(body.lessonSummary) && `Contenu de la leçon (suis ses notations) :\n${field(body.lessonSummary)}`,
    ].filter(Boolean).join('\n');

    // Free plan always uses Haiku; paid plans use Sonnet for the reasoning modes.
    const useSonnet = tier !== TIERS.free && SONNET_MODES.has(mode);
    const model = useSonnet ? MODELS.sonnet : MODELS.haiku;
    const response = await anthropic.messages.create({
      model: model.id,
      // Never more than the student has left today and this month.
      max_tokens: Math.max(500, Math.min(MAX_ANSWER_TOKENS, affordableOutput(left, model))),
      // Solving and correcting need careful reasoning; the rest less so.
      output_config: { effort: mode === 'solve' || mode === 'check' ? 'high' : 'medium' },
      system: [SYSTEM_PROMPT, MODES[mode], context].filter(Boolean).join('\n\n'),
      messages: history,
    });

    if (response.stop_reason === 'refusal') {
      return json({ reply: 'عذراً، لا أستطيع المساعدة في هذا الطلب. اسألني عن دروسك أو أمورك الدراسية.' });
    }

    const reply = response.content
      .filter((block) => block.type === 'text')
      .map((block) => (block as { text: string }).text)
      .join('\n')
      .trim();

    // Record what this answer really used (tokens and estimated cost).
    const inTok = response.usage?.input_tokens ?? 0;
    const outTok = response.usage?.output_tokens ?? 0;
    const costUsd = (inTok * model.inPrice + outTok * model.outPrice) / 1_000_000;
    await supabase.from('assistant_costs').insert({
      user_id: userId,
      kind: attachment ? 'file' : 'question',
      model: model.id,
      input_tokens: inTok,
      output_tokens: outTok,
      cost_usd: costUsd,
    });

    const after = await remainingBudget(supabase, userId, tier, bonus);
    return json({
      reply: reply || 'لم أتمكن من صياغة إجابة، حاول إعادة صياغة سؤالك.',
      ...percentLeft(after, tier, bonus),
    });
  } catch (error) {
    // Logged so the cause (key, credit, model, limits) shows in the function logs.
    console.error('assistant error:', error instanceof Error ? error.message : error);
    if (error instanceof Anthropic.RateLimitError) {
      return json({ message: 'المساعد مشغول الآن، حاول بعد قليل.' }, 503);
    }
    if (error instanceof Anthropic.APIError) {
      console.error('anthropic status:', error.status, error.message);
      return json({ message: 'تعذر الوصول إلى المساعد.' }, 502);
    }
    return json({ message: error instanceof Error ? error.message : 'Erreur' }, 500);
  }
});

type Budget = { dailyUsd: number; monthlyUsd: number };

/// Output tokens the balance can pay for on this model, after the typical input.
function affordableOutput(leftUsd: number, model: { inPrice: number; outPrice: number }) {
  const inputCost = (ASSUMED_INPUT_TOKENS * model.inPrice) / 1_000_000;
  return Math.floor(((leftUsd - inputCost) / model.outPrice) * 1_000_000);
}

/// Dollars left today and this month. Each answer's recorded cost counts;
/// bonus tokens (referrals) are valued at the Sonnet price and add to the month.
/// The season bonus multiplies both caps.
async function remainingBudget(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  tier: Tier,
  bonus: number,
): Promise<Budget> {
  const now = new Date();
  const dayStart = now.toISOString().slice(0, 10);
  const monthStart = `${dayStart.slice(0, 8)}01`;
  const { data: costs } = await supabase
    .from('assistant_costs')
    .select('day, cost_usd')
    .eq('user_id', userId)
    .gte('day', monthStart);
  const { data: bonuses } = await supabase
    .from('assistant_bonus')
    .select('input_tokens, output_tokens')
    .eq('user_id', userId)
    .gte('created_at', `${monthStart}T00:00:00Z`);
  let dayUsd = 0, monthUsd = 0, extraUsd = 0;
  for (const c of costs ?? []) {
    const usd = Number(c.cost_usd ?? 0);
    monthUsd += usd;
    if (c.day === dayStart) dayUsd += usd;
  }
  for (const b of bonuses ?? []) {
    extraUsd +=
      ((b.input_tokens ?? 0) * MODELS.sonnet.inPrice +
        (b.output_tokens ?? 0) * MODELS.sonnet.outPrice) / 1_000_000;
  }
  return {
    dailyUsd: dailyUsd(tier) * bonus - dayUsd,
    monthlyUsd: monthlyUsd(tier) * bonus + extraUsd - monthUsd,
  };
}

/// What the app shows: how much of today's and this month's usage is left.
function percentLeft(b: Budget, tier: Tier, bonus: number) {
  const share = (left: number, cap: number) => Math.max(0, Math.min(1, left / cap));
  return {
    dailyLeftPct: Math.floor(share(b.dailyUsd, dailyUsd(tier) * bonus) * 100),
    monthlyLeftPct: Math.floor(share(b.monthlyUsd, monthlyUsd(tier) * bonus) * 100),
  };
}

/// The student's tier: their own override, else the default in settings.
async function tierFor(supabase: ReturnType<typeof createClient>, override: unknown): Promise<Tier> {
  if (typeof override === 'string' && TIERS[override]) return TIERS[override];
  const { data } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', 'assistantDefaultTier')
    .maybeSingle();
  const name = String(data?.value ?? '').trim();
  return TIERS[name] ?? TIERS.standard;
}

/// Season bonus from the admin settings (1 to 5); 1 when missing or invalid.
async function seasonBonus(supabase: ReturnType<typeof createClient>): Promise<number> {
  const { data } = await supabase
    .from('app_settings')
    .select('value')
    .eq('key', 'assistantBonus')
    .maybeSingle();
  const factor = Number(data?.value);
  return Number.isFinite(factor) && factor >= 1 && factor <= 5 ? Math.round(factor) : 1;
}

function parseAttachment(image: unknown, document: unknown, name: unknown): Attachment | null {
  for (const value of [image, document]) {
    if (typeof value !== 'string' || value.length === 0) continue;
    const match = /^data:([a-z]+\/[a-z0-9.+-]+);base64,(.+)$/s.exec(value);
    if (!match || match[2].length > MAX_FILE_CHARS) return null;
    if (IMAGE_TYPES.includes(match[1])) {
      return { kind: 'image', type: match[1] as 'image/png', data: match[2] };
    }
    if (match[1] === 'application/pdf') {
      return { kind: 'pdf', data: match[2], name: String(name ?? 'document.pdf').slice(0, 120) };
    }
    return null;
  }
  return null;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
