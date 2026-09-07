# Data notes

What each language's verb data actually is, relative to its source, and where it was
hand-modified. Written as a reference for future changes, not user-facing.

## Spanish (`data/verbs.json`, `data/verbs.sample.json`)

- Source: Fred Jehle's Spanish Verb Database (`jehle_verb_database.csv`), CC BY-NC-SA 3.0.
- Forms are **looked up verbatim** from the CSV — nothing is computed. Infinitive,
  English gloss, gerund, past participle, and every mood/tense form for a verb are
  copied as-is from the source rows.
- 100 of the CSV's ~638 verbs are included, hand-curated (not a frequency corpus — see
  the "verb selection" note below). `rank` = position in the curated list.
- The CSV actually contains many more moods/tenses per verb than the app drills
  (subjunctive, imperative, perfect tenses); `build_data.ps1` captures all of them into
  the JSON even though `app.js` only actively uses 5 tenses + gerund + participle, so
  widening `ACTIVE_TENSES` later doesn't require touching the data pipeline.

## French (`data/verbs.french.json`)

- Source: Verbiste's data as republished by `gauthier-th/conjugation-fr` (JSON,
  GPL-2.0), itself derived from the original Verbiste project.
- Forms are **computed**, not looked up: the source stores conjugation *templates*
  (suffixes relative to a radical) rather than full tables per verb. `radical =
  infinitive minus the template's own infinitive-ending`; each form = `radical +
  template's stored suffix`.
- Passé composé is not a template entry (it's a compound tense) — built manually as
  `[auxiliary's present tense] + [past participle]`.
  - **Bug, now fixed**: originally used the masculine *singular* participle for every
    person. Être-verbs need the masculine *plural* variant for nous/vous/ils ("sommes
    allés", not "allé"). Avoir-verbs never agree, so they were never affected.
  - The être-verb list (which verbs take être vs. avoir) is hand-maintained, not
    derived from the source data.
  - Third person is drilled as bare "il"/"ils", not "il / elle" — the stored
    participle is masculine, which would be wrong for "elle" on être-verbs.
  - "Être" itself takes **avoir** as its own auxiliary ("j'ai été") — this is
    correct French grammar, not a gap.
- The source conflates gerund and present participle under one `<participle>`
  element — French doesn't have a distinct machine-readable "gérondif" field. The
  drilled form is labeled "Participe présent" (not "Gérondif") because the stored
  string is the bare participle (parlant), not the "en + participle" adverbial form.
- 100 verbs, hand-curated. `rank` = position in the curated list.

## Italian (`data/verbs.italian.json`)

- Source: Verbiste's own Italian data (`RemiCardona/verbiste`, the original
  multi-language project — not a JS fork), raw XML, GPL-2.0.
- Same computed-forms approach as French (radical + template suffix), parsed directly
  from XML since no pre-converted JSON exists for Italian.
- **Known data gap**: the source file has a block of verbs the Verbiste maintainers
  themselves marked "en attente" (pending) and commented out of the active data —
  including some very common ones. Confirmed unavailable: *nascere, morire, rimanere,
  salire, scendere, decidere, offrire, ricevere, esistere, considerare, indicare,
  vincere, crescere, muovere, promettere, rompere, costruire, distruggere, piangere,
  gridare, perdere, ridere*. These were substituted with other common verbs
  (*accendere, apparire, coprire, fermare, lavare, preferire, preparare, provare,
  riposare, sognare, sperare, sposare, telefonare, temere, togliere, tradurre, usare,
  vestire, visitare, ottenere, contenere, mantenere*). Usable pool is ~251 verbs vs.
  Spanish's 638 and French's 7000+.
- Passato prossimo built the same way as French's passé composé, including the same
  plural-participle agreement fix for essere-verbs.
  - **Language difference, not a bug**: unlike French's "être" (which takes avoir),
    Italian's "essere" takes **itself** as auxiliary ("sono stato", not "ho stato").
  - Third person drilled as bare "lui", same reasoning as French's "il".
- Unlike French, the source schema keeps gerundio (`<gerund>`, e.g. "parlando") and
  present participle (`<participle><present-participle>`, e.g. "parlante") as
  genuinely separate fields. "Gerundio" is drilled from the `<gerund>` field
  specifically — both the correct term and the correct field, no hedge needed.
- 100 verbs, hand-curated (selection only — see ranking note below).

## Verb selection (all three languages)

Which 100 verbs are *included* is still hand-curated from general knowledge for all
three languages — nobody's run a proper frequency-based selection pass yet. The
`rank` field (what order they're presented in / which ones "Top 20/50/100" includes)
is a separate concern from selection, and is designed so its source can be swapped
without touching any app logic: whichever `scripts/build_*.ps1` sets `rank`, the
verb-list-size selector just filters `rank <= N` regardless of how rank was derived.

**Italian now uses this seam for real**: `rank` comes from LeFFI
(`matteo-pellegrini/LeFFI`, CC BY-SA 4.0) frequency data (COLFIS corpus), not
hand-curated guessing. Spanish and French still use hand-curated order as rank.

### LeFFI: usable for ranking, not for verifying written forms

LeFFI was evaluated as a way to cross-check Italian's computed forms, since it's an
independent academic source unrelated to Verbiste. That didn't work out: LeFFI's
`forms.csv` only stores **phonetic** transcriptions (e.g. "ho" → "o", silent h
correctly dropped in speech; "faccio" → "fattʃo", IPA affricate; "può" → "pwo",
semivowel, no written accent) — there is no orthographic-spelling column anywhere in
the dataset (confirmed against the full file listing, not just the files pulled
locally). Comparing our spelled forms against LeFFI's phonetic ones directly produces
mostly false positives (1289 of 2600 comparisons "differed," nearly all just
spelling-vs-phonetics, not real errors) and was abandoned rather than pursued further
(e.g. building an IPA-to-spelling converter) — that's a real, error-prone project of
its own, not a quick verification step, and wrong output dressed up as "verified"
would be worse than the status quo.

**Still valid and in use**: LeFFI's `lexemes.csv` (verb + frequency, no phonetics
involved) is exactly what powers the Italian ranking above.

**Known opportunity, not yet acted on**: all 22 of Italian's Verbiste-gap verbs
(nascere, morire, rimanere, etc. — see above) exist in LeFFI with real frequency
data, several fairly common (rimanere: 1607, perdere: 1386, decidere: 1331). LeFFI
can't supply their *written* forms (see above), but it does confirm they're
legitimate, sometimes-more-common-than-current-substitutes verbs worth adding back
in if someone authors their conjugations by hand the way the current 100 were.
