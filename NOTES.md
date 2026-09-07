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
- 100 verbs, hand-curated. `rank` = position in the curated list.

## Verb selection (all three languages)

None of the three verb lists come from an actual frequency corpus — they're
hand-curated from general knowledge of common verbs, ordered roughly most-to-least
common. The `rank` field exists specifically so this can be swapped for a real
corpus (e.g. SUBTLEX-ESP/FR/IT) later without touching any app logic: replace the
curated array in the relevant `scripts/build_*.ps1`, and the verb-list-size selector
("Top 20/50/100") keeps working unchanged since it just filters `rank <= N`.
