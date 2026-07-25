// Surfaces any uncaught error directly on the page as a visible banner.
// Without this, a script error on a device we can't attach devtools to
// (e.g. a phone) just looks like "nothing happens" with no way to diagnose it.
function showFatalError(message) {
  let banner = document.getElementById("fatalErrorBanner");
  if (!banner) {
    banner = document.createElement("div");
    banner.id = "fatalErrorBanner";
    banner.style.cssText =
      "position:fixed;top:0;left:0;right:0;background:#c1402e;color:#fff;" +
      "padding:0.75rem 1rem;font:13px/1.4 monospace;z-index:9999;white-space:pre-wrap;";
    document.body.prepend(banner);
  }
  banner.textContent = String(message);
}
window.addEventListener("error", (e) => {
  showFatalError(`${e.message} (${(e.filename || "").split("/").pop()}:${e.lineno})`);
});

const MASTERY_KEY = "conjugue_mastery_v1_fr";
const STREAK_KEY = "conjugue_streak_v1_fr";
const STRICT_KEY = "conjugue_strict_v1_fr";

// v1 drills 4 simple tenses plus passé composé. French's everyday past tense
// is compound (auxiliary + participle), unlike Spanish's simple pretérito,
// so passé composé stands in for it here rather than the rarely-spoken
// passé simple. Third person is "il"/"ils" rather than "il / elle" etc.
// specifically because the stored passé composé participle is masculine and
// would be wrong for "elle" on être-verbs (e.g. "elle est allée", not
// "allé") — offering the ambiguous label would be actively misleading.
const ACTIVE_MOOD = "Indicatif";
const ACTIVE_TENSES = ["Présent", "Passé composé", "Imparfait", "Futur", "Conditionnel"];

// Gerund/participle don't conjugate by pronoun, so they're not part of the
// per-pronoun forms table — each verb just carries a single string for each,
// looked up directly off the verb object rather than through ACTIVE_MOOD.
// "Participe présent" rather than "Gérondif" since the stored form is the
// bare participle (parlant), not the "en + participle" adverbial use.
const EXTRA_FORMS = [
  { key: "gerund", label: "Participe présent" },
  { key: "participle", label: "Participe passé" },
];
const TOTAL_STEPS = ACTIVE_TENSES.length + EXTRA_FORMS.length;

const PRONOUNS = [
  { key: "1s", label: "je" },
  { key: "2s", label: "tu" },
  { key: "3s", label: "il" },
  { key: "1p", label: "nous" },
  { key: "2p", label: "vous" },
  { key: "3p", label: "ils" },
];

// Vowel/diacritic folding only — ç is folded too (its distinction from "c"
// is phonetic spelling, not a separate letter the way ñ is in Spanish).
const ACCENT_FOLD = {
  é: "e", è: "e", ê: "e", ë: "e",
  à: "a", â: "a", ä: "a",
  î: "i", ï: "i",
  ô: "o", ö: "o",
  ù: "u", û: "u", ü: "u",
  ç: "c",
};
function foldAccents(s) {
  return s.replace(/[éèêëàâäîïôöùûüç]/g, (c) => ACCENT_FOLD[c]);
}

// Some browsers block localStorage entirely on file:// origins (the
// standalone build is opened by double-clicking, not served), so every
// access is wrapped rather than left to throw.
function safeGet(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}
function safeSet(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // progress just won't persist this session
  }
}

function loadMastery() {
  try {
    return JSON.parse(safeGet(MASTERY_KEY)) || {};
  } catch {
    return {};
  }
}
function saveMastery(m) {
  safeSet(MASTERY_KEY, JSON.stringify(m));
}
function recordResult(infinitive, correct) {
  const m = loadMastery();
  const entry = m[infinitive] || { correct: 0, incorrect: 0 };
  if (correct) entry.correct++;
  else entry.incorrect++;
  m[infinitive] = entry;
  saveMastery(m);
}

function getStreak() {
  return parseInt(safeGet(STREAK_KEY) || "0", 10);
}
function setStreak(n) {
  safeSet(STREAK_KEY, String(n));
  document.getElementById("streak").textContent = `🔥 ${n}`;
}

let verbs = [];
let round = null; // { verb, pronoun, tenseIndex, correctCount }
let waitingToAdvance = false;

const els = {
  headerVerb: document.getElementById("headerVerb"),
  headerPronoun: document.getElementById("headerPronoun"),
  headerEnglish: document.getElementById("headerEnglish"),
  startRoundBtn: document.getElementById("startRoundBtn"),
  roundIntro: document.getElementById("roundIntro"),
  drill: document.getElementById("drill"),
  tenseLabel: document.getElementById("tenseLabel"),
  answerForm: document.getElementById("answerForm"),
  answerInput: document.getElementById("answerInput"),
  feedback: document.getElementById("feedback"),
  progressDots: document.getElementById("progressDots"),
  roundSummary: document.getElementById("roundSummary"),
  summaryLine: document.getElementById("summaryLine"),
  nextRoundBtn: document.getElementById("nextRoundBtn"),
  strictAccents: document.getElementById("strictAccents"),
  checkBtn: document.getElementById("checkBtn"),
};

function pickWeightedVerb(excludeInfinitive) {
  const mastery = loadMastery();
  const weights = verbs.map((v) => {
    const m = mastery[v.infinitive] || { correct: 0, incorrect: 0 };
    const total = m.correct + m.incorrect;
    const errorRate = total ? m.incorrect / total : 0.5;
    let w = 1 + errorRate * 4;
    if (v.infinitive === excludeInfinitive) w *= 0.15;
    return w;
  });
  const totalWeight = weights.reduce((a, b) => a + b, 0);
  let r = Math.random() * totalWeight;
  for (let i = 0; i < verbs.length; i++) {
    r -= weights[i];
    if (r <= 0) return verbs[i];
  }
  return verbs[verbs.length - 1];
}

function pickPronoun() {
  return PRONOUNS[Math.floor(Math.random() * PRONOUNS.length)];
}

function prepareRound() {
  const prevVerb = round ? round.verb.infinitive : null;
  const verb = pickWeightedVerb(prevVerb);
  const pronoun = pickPronoun();
  round = { verb, pronoun, tenseIndex: 0, correctCount: 0 };

  els.headerVerb.textContent = verb.infinitive;
  els.headerPronoun.textContent = pronoun.label;
  els.headerEnglish.textContent = verb.english;

  els.roundSummary.classList.add("hidden");
  els.drill.classList.add("hidden");
  els.roundIntro.classList.remove("hidden");
  playEnter(els.roundIntro);
}

function playEnter(el) {
  el.classList.remove("enter");
  void el.offsetWidth; // restart the CSS animation
  el.classList.add("enter");
}

function buildDots() {
  els.progressDots.innerHTML = "";
  for (let i = 0; i < TOTAL_STEPS; i++) {
    const dot = document.createElement("span");
    dot.className = "dot";
    els.progressDots.appendChild(dot);
  }
}

function updateDot(index, state) {
  const dot = els.progressDots.children[index];
  dot.classList.remove("current", "done-correct", "done-incorrect");
  dot.classList.add(state);
}

function startRound() {
  els.roundIntro.classList.add("hidden");
  els.drill.classList.remove("hidden");
  buildDots();
  showCurrentTense();
  playEnter(els.drill);
}

function showCurrentTense() {
  const idx = round.tenseIndex;
  els.tenseLabel.textContent =
    idx < ACTIVE_TENSES.length ? ACTIVE_TENSES[idx] : EXTRA_FORMS[idx - ACTIVE_TENSES.length].label;
  els.feedback.classList.add("hidden");
  els.feedback.innerHTML = "";
  els.answerInput.value = "";
  els.answerInput.readOnly = false;
  els.answerInput.focus();
  els.checkBtn.textContent = "Check";
  updateDot(round.tenseIndex, "current");
  waitingToAdvance = false;
}

function checkAnswer(userInput, correctForm, strict) {
  const rawUser = userInput.trim().toLowerCase();
  const rawCorrect = correctForm.trim().toLowerCase();
  if (rawUser === rawCorrect) return { correct: true, accentPerfect: true };
  if (strict) return { correct: false, accentPerfect: false };
  if (foldAccents(rawUser) === foldAccents(rawCorrect)) {
    return { correct: true, accentPerfect: false };
  }
  return { correct: false, accentPerfect: false };
}

function submitAnswer() {
  const idx = round.tenseIndex;
  const isExtra = idx >= ACTIVE_TENSES.length;
  const correctForm = isExtra
    ? round.verb[EXTRA_FORMS[idx - ACTIVE_TENSES.length].key]
    : round.verb.forms[ACTIVE_MOOD][ACTIVE_TENSES[idx]][round.pronoun.key];
  const strict = els.strictAccents.checked;
  const result = checkAnswer(els.answerInput.value, correctForm, strict);

  recordResult(round.verb.infinitive, result.correct);
  setStreak(result.correct ? getStreak() + 1 : 0);

  els.feedback.classList.remove("hidden", "correct", "incorrect");
  if (result.correct && result.accentPerfect) {
    els.feedback.classList.add("correct");
    els.feedback.textContent = "Correct !";
  } else if (result.correct) {
    els.feedback.classList.add("correct");
    els.feedback.innerHTML = `Correct ! <span class="correction">Watch the accent: ${correctForm}</span>`;
  } else {
    els.feedback.classList.add("incorrect");
    const hint = isExtra ? correctForm : `${round.pronoun.label} → ${correctForm}`;
    els.feedback.innerHTML = `Not quite <span class="correction">${hint}</span>`;
  }

  updateDot(idx, result.correct ? "done-correct" : "done-incorrect");
  if (result.correct) round.correctCount++;

  els.answerInput.readOnly = true;
  const isLast = idx >= TOTAL_STEPS - 1;
  els.checkBtn.textContent = isLast ? "See results" : "Next tense →";
  waitingToAdvance = true;
}

function advance() {
  round.tenseIndex++;
  if (round.tenseIndex >= TOTAL_STEPS) {
    finishRound();
  } else {
    showCurrentTense();
  }
}

function finishRound() {
  els.drill.classList.add("hidden");
  els.roundSummary.classList.remove("hidden");
  els.summaryLine.textContent = `${round.correctCount} / ${TOTAL_STEPS} correct for "${round.verb.infinitive}"`;
  playEnter(els.roundSummary);
}

els.startRoundBtn.addEventListener("click", startRound);
els.nextRoundBtn.addEventListener("click", () => {
  prepareRound();
});

// Neither button lives in a form, so Enter doesn't reach them by default.
// preventDefault() here also stops a focused button's own native Enter->click
// from firing a second time on top of this (the exact double-fire bug the
// drill screen's Enter handling had earlier).
document.addEventListener("keydown", (e) => {
  if (e.key !== "Enter") return;
  if (!els.roundIntro.classList.contains("hidden")) {
    e.preventDefault();
    startRound();
  } else if (!els.roundSummary.classList.contains("hidden")) {
    e.preventDefault();
    prepareRound();
  }
});

els.answerForm.addEventListener("submit", (e) => {
  e.preventDefault();
  if (waitingToAdvance) {
    advance();
  } else {
    submitAnswer();
  }
});

els.strictAccents.addEventListener("change", () => {
  safeSet(STRICT_KEY, els.strictAccents.checked ? "1" : "0");
});

function initWithData(data) {
  verbs = data.verbs;
  els.strictAccents.checked = safeGet(STRICT_KEY) === "1";
  setStreak(getStreak());
  prepareRound();
}

// The standalone build sets window.EMBEDDED_VERB_DATA before this script
// runs, so it never needs fetch (which fails outright on file:// origins).
if (window.EMBEDDED_VERB_DATA) {
  initWithData(window.EMBEDDED_VERB_DATA);
} else {
  fetch("data/verbs.french.json")
    .then((r) => r.json())
    .then(initWithData)
    .catch((err) => {
      showFatalError("Couldn't load verb data: " + err.message);
      console.error(err);
    });
}
