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

// Token allowance (like Claude's usage limits). Each subscribed student has a
// monthly pool and a daily cap, for input and output tokens separately. Output
// tokens cost five times more, so they have smaller caps.
type Tier = { monthlyIn: number; monthlyOut: number; dailyIn: number; dailyOut: number };
const TIERS: Record<string, Tier> = {
  basic: { monthlyIn: 2_000_000, monthlyOut: 200_000, dailyIn: 80_000, dailyOut: 8_000 },
  standard: { monthlyIn: 4_000_000, monthlyOut: 400_000, dailyIn: 160_000, dailyOut: 16_000 },
  pro: { monthlyIn: 8_000_000, monthlyOut: 800_000, dailyIn: 320_000, dailyOut: 32_000 },
  // Free plan: a few questions a day, enough to try the assistant (about
  // 3 to 4 answers a day, or one photo or short PDF).
  free: { monthlyIn: 600_000, monthlyOut: 60_000, dailyIn: 30_000, dailyOut: 3_000 },
};
// Longest answer, in output tokens.
const MAX_ANSWER_TOKENS = 4000;
// Below these, a request is refused rather than run on a near-empty balance.
const MIN_INPUT_LEFT = 3_000;
const MIN_OUTPUT_LEFT = 500;
// Files need room for their pages.
const MIN_FILE_INPUT_LEFT = 20_000;
const MAX_HISTORY = 20;
// Base64 length of the largest attachment accepted (~7.5 MB once decoded).
const MAX_FILE_CHARS = 10_000_000;
const IMAGE_TYPES = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];

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

    // Subscribers get their tier; everyone else gets the free plan.
    const { count: activeSubs } = await supabase
      .from('subject_subscriptions')
      .select('id', { count: 'exact', head: true })
      .eq('student_id', userId)
      .eq('status', 'active');
    const tier = (activeSubs ?? 0) > 0
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
    const inputLeft = Math.min(budget.dailyIn, budget.monthlyIn);
    const outputLeft = Math.min(budget.dailyOut, budget.monthlyOut);
    if (inputLeft < MIN_INPUT_LEFT || outputLeft < MIN_OUTPUT_LEFT) {
      return json({ message: 'نفد رصيدك من الاستعمال. يتجدد الرصيد اليومي غداً.' }, 429);
    }
    if (attachment && inputLeft < MIN_FILE_INPUT_LEFT) {
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

    const response = await anthropic.messages.create({
      model: 'claude-haiku-5-5',
      // Never more than the student has left today and this month.
      max_tokens: Math.max(500, Math.min(MAX_ANSWER_TOKENS, outputLeft)),
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
    const costUsd = (inTok * 0.1 + outTok * 0.5) / 1_000_000;
    await supabase.from('assistant_costs').insert({
      user_id: userId,
      kind: attachment ? 'file' : 'question',
      model: 'claude-haiku-5-5',
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
    if (error instanceof Anthropic.RateLimitError) {
      return json({ message: 'المساعد مشغول الآن، حاول بعد قليل.' }, 503);
    }
    if (error instanceof Anthropic.APIError) {
      return json({ message: 'تعذر الوصول إلى المساعد.' }, 502);
    }
    return json({ message: error instanceof Error ? error.message : 'Erreur' }, 500);
  }
});

type Budget = {
  dailyIn: number;
  dailyOut: number;
  monthlyIn: number;
  monthlyOut: number;
};

/// Tokens left today and this month. Bonus tokens (referrals) add to the
/// monthly pool; the season bonus multiplies both kinds of caps.
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
    .select('day, input_tokens, output_tokens')
    .eq('user_id', userId)
    .gte('day', monthStart);
  const { data: bonuses } = await supabase
    .from('assistant_bonus')
    .select('input_tokens, output_tokens')
    .eq('user_id', userId)
    .gte('created_at', `${monthStart}T00:00:00Z`);
  let dayIn = 0, dayOut = 0, monthIn = 0, monthOut = 0;
  for (const c of costs ?? []) {
    monthIn += c.input_tokens ?? 0;
    monthOut += c.output_tokens ?? 0;
    if (c.day === dayStart) {
      dayIn += c.input_tokens ?? 0;
      dayOut += c.output_tokens ?? 0;
    }
  }
  let extraIn = 0, extraOut = 0;
  for (const b of bonuses ?? []) {
    extraIn += b.input_tokens ?? 0;
    extraOut += b.output_tokens ?? 0;
  }
  return {
    dailyIn: tier.dailyIn * bonus - dayIn,
    dailyOut: tier.dailyOut * bonus - dayOut,
    monthlyIn: tier.monthlyIn * bonus + extraIn - monthIn,
    monthlyOut: tier.monthlyOut * bonus + extraOut - monthOut,
  };
}

/// What the app shows: how much of today's and this month's allowance is left
/// (the tighter of input and output), as a percentage.
function percentLeft(b: Budget, tier: Tier, bonus: number) {
  const share = (left: number, cap: number) => Math.max(0, Math.min(1, left / cap));
  const daily = Math.min(
    share(b.dailyIn, tier.dailyIn * bonus),
    share(b.dailyOut, tier.dailyOut * bonus),
  );
  const monthly = Math.min(
    share(b.monthlyIn, tier.monthlyIn * bonus),
    share(b.monthlyOut, tier.monthlyOut * bonus),
  );
  return {
    dailyLeftPct: Math.floor(daily * 100),
    monthlyLeftPct: Math.floor(monthly * 100),
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
