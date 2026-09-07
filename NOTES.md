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

- **Source (current): Morph-it!** (Baroni & Zanchetta, dual CC BY-SA 2.0 / LGPL),
  `data/morphit/morph-it_048.txt` — a tagged wordform lexicon, ~505k entries. Forms
  are **looked up verbatim**, the same architecture as Spanish, not computed.
- **Previously**: Verbiste's own Italian data (`RemiCardona/verbiste`, GPL-2.0), same
  radical+template computation as French. Switched away from this — see "Why Italian
  moved off Verbiste" below for what went wrong with it.
- Morph-it! ships as ISO-8859-1, not UTF-8; `build_italian_data.ps1` decodes it
  directly rather than trusting `Get-Content -Encoding` (Windows PowerShell 5.1's
  `-Encoding` only accepts a fixed named-encoding enum, not an arbitrary
  `[System.Text.Encoding]`).
- Some Morph-it! cells list more than one spelling (e.g. an apocopated variant
  alongside the standard one, like "dan" beside "danno"); the build picks the
  longest, which matched the standard/modern form in every case checked.
- **Morph-it! itself has a confirmed bug**: it duplicates "prenderà" under both 1s
  and 3s future tags, missing "prenderò" entirely. Same pattern hit rispondere,
  temere, and accendere. `build_italian_data.ps1` hand-overrides these 4 specific
  cells and sanity-checks that 1st/3rd person singular are never identical for any
  verb/tense (linguistically impossible in Italian) so a future re-run would catch
  new instances of this same failure mode rather than silently trusting them.
- Passato prossimo still built manually (it's periphrastic, not a single lexicon
  entry in Morph-it! either): `[auxiliary present tense] + [past participle]`, both
  now looked up verbatim. Includes the same plural-participle agreement fix as
  French (see below) for essere-verbs' noi/voi/loro.
  - **Language difference, not a bug**: unlike French's "être" (which takes avoir),
    Italian's "essere" takes **itself** as auxiliary ("sono stato", not "ho stato").
  - Third person drilled as bare "lui", same reasoning as French's "il".
  - The essere-verb list (which verbs take essere vs. avere) is hand-maintained —
    Morph-it! doesn't tag which auxiliary a verb takes, only which verbs (essere,
    avere, venire) function as auxiliaries themselves.
- Like the old Verbiste source (and unlike French's), Morph-it! keeps gerundio
  (`ger+pres` tag, e.g. "parlando") and present participle (`part+pres`, e.g.
  "parlante") as genuinely separate entries. "Gerundio" is looked up from the
  `ger+pres` tag specifically — both the correct term and the correct source, no
  hedge needed (contrast French's "Participe présent" compromise above).
- 100 verbs, hand-curated (selection only — see "Verb selection" below). `rank`
  comes from LeFFI frequency data, unaffected by the Morph-it! switch (see below).

### Why Italian moved off Verbiste

A verification pass against Morph-it! (see below) found real bugs in the old
Verbiste-computed forms, and traced the cause: **chiedere, chiudere, coprire,
produrre, and tradurre each appear twice in Verbiste's source XML with two
different, conflicting templates**, and the old script's naive lookup
(`$verbsByInfinitive[$v.i] = $v.t`) silently kept whichever came last in the file
— with no way to know it picked wrong without an external check. This is a
different, worse problem than the already-known missing-verb gap (below): it's
not just incomplete, it was producing confidently-wrong output for verbs it did
claim to cover. That, combined with Verbiste's already-known gap (following),
motivated the switch to verbatim lookup — the same reasoning Spanish's
architecture already reflected.

**Verbiste's known gap** (relevant only to the old source, kept for history):
its source file has a block of verbs the maintainers themselves marked "en
attente" (pending) and commented out of the active data — including some very
common ones (nascere, morire, rimanere, salire, scendere, decidere, offrire,
ricevere, esistere, considerare, indicare, vincere, crescere, muovere,
promettere, rompere, costruire, distruggere, piangere, gridare, perdere,
ridere). The current 100-verb list still substitutes other common verbs for
these (accendere, apparire, coprire, fermare, lavare, preferire, preparare,
provare, riposare, sognare, sperare, sposare, telefonare, temere, togliere,
tradurre, usare, vestire, visitare, ottenere, contenere, mantenere) — that
selection wasn't revisited when the forms source changed, to keep the change
scoped to lookup-vs-computed. Morph-it! *does* have all of the gap verbs
available now, so revisiting the selection to add them back is a real,
separate option.

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

### French: a lookup option now exists, not yet acted on

Unlike LeFFI, the `french-verbs-lefff` npm package (Ludan Stoecklé, MIT-licensed
wrapper) bundles Lefff's (Lexique des Formes Fléchies du Français, Benoît Sagot /
INRIA) `conjugations.json` — a genuinely verbatim, per-verb lookup table with real
written forms for every tense we need, including the same 4-way past-participle
split (masc-sg/masc-pl/fem-sg/fem-pl) our passé composé agreement logic already
expects. The data itself is under **LGPL-LR** (Lesser GPL for Linguistic
Resources) — a real, established license for exactly this kind of resource,
same spirit (attribution + share-alike) as the GPL-2.0 Verbiste data already in
use. This would let French move to verbatim lookup the same way Italian just did,
which would likely close off the same *class* of bug (wrong template picked for
an ambiguous verb) that motivated Italian's switch — French's current Verbiste
data hasn't been checked for the same "verb listed twice with conflicting
templates" issue Italian had, so it's unknown whether this same failure mode is
lurking there too. Not done: this note exists to make the option visible, not
to imply it's necessary or already evaluated for correctness the way Italian's
switch was.

Also evaluated for French, both authoritative but with no stated license (manual
reference only, not bulk-usable): the Académie française data
(`ShingZhanho/verbe-conjugaison-academie-francaise`) and RALI's Dubois "Les
Verbes Français" (LVF) lexicon — the latter classifies verbs by conjugation group
and auxiliary (avoir/être) but doesn't store actual conjugated forms, so it could
only ever cross-check the être-verb list, not spelling.
