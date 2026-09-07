# Builds data/verbs.italian.json from the Verbiste project's own Italian data
# (raw_verbs_it_*.xml, downloaded from github.com/RemiCardona/verbiste --
# the original multi-language Verbiste project, not the JS-only French fork).
# Same radical+template rule system as build_french_data.ps1: a verb points
# at a template ("radical-sample:ending"), and forms are computed as
# [infinitive minus template's own ending] + [template's stored suffix].
#
# Note on data completeness: verbs-it.xml has a block of verbs the upstream
# maintainers themselves marked "en attente" (pending) and commented out --
# including some very common ones (nascere, morire, rimanere, salire,
# scendere, decidere, offrire, ricevere...). Those are genuinely unavailable
# here, not missed by this script. The curated list below substitutes other
# common verbs for gaps hit during curation; usable pool is ~251 verbs,
# smaller than Spanish's 638 or French's 7000+.
#
# Passato prossimo is not itself a template entry (it's a compound tense), so
# it's built here as [auxiliary present tense] + [masculine singular past
# participle], same construction as French's passe compose and for the same
# reason: Italian's everyday spoken past is this compound form, not the
# literary passato remoto. Third person is drilled as bare "lui" rather than
# "lui / lei", specifically because the stored participle is masculine and
# would be wrong for "lei" on essere-verbs (e.g. "lei e` andata", not
# "andato") -- offering the ambiguous label would be actively misleading.
#
# Gerundio (amando) is genuinely distinct from the present participle
# (amante) in this dataset's own schema (<gerund> vs <participle>), unlike
# French where the two get conflated under one <participle> element -- so
# unlike app.french.js's "Participe present" hedge, "Gerundio" here is both
# the correct term and the correct field, matching Spanish's usage exactly.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$outPath = Join-Path $root "data\verbs.italian.json"

[xml]$verbsIt = Get-Content -Raw -Path (Join-Path $root "raw_verbs_it_list.xml") -Encoding UTF8
[xml]$conjIt = Get-Content -Raw -Path (Join-Path $root "raw_verbs_it_templates.xml") -Encoding UTF8

function CH([int]$code) { return [string][char]$code }

$templatesByName = @{}
foreach ($t in $conjIt.'conjugation-it'.template) { $templatesByName[$t.name] = $t }

$verbsByInfinitive = @{}
foreach ($v in $verbsIt.'verbs-it'.v) { $verbsByInfinitive[$v.i] = $v.t }

# Ordered most-to-least common (hand-curated, not corpus-derived -- see
# README). Insertion order becomes each verb's "rank" field in the output, so
# the app's verb-list-size selector (top 20/50/100) is just "rank <= N" --
# swapping this for a real frequency corpus later only means replacing this
# list, not touching any selection logic downstream. Several entries here
# stand in for common verbs the source data doesn't have active (see note
# above) -- e.g. "accendere" instead of "rimanere".
$verbList = [ordered]@{
  "essere" = "to be"
  "avere" = "to have"
  "fare" = "to do, make"
  "andare" = "to go"
  "potere" = "to be able to, can"
  "volere" = "to want"
  "dovere" = "to have to, must"
  "sapere" = "to know (a fact)"
  "dire" = "to say, tell"
  "dare" = "to give"
  "stare" = "to stay, be (state)"
  "vedere" = "to see"
  "venire" = "to come"
  "uscire" = "to go out, leave"
  "parlare" = "to speak"
  "mettere" = "to put, place"
  "prendere" = "to take"
  "credere" = "to believe"
  "sentire" = "to feel, hear"
  "capire" = "to understand"
  "accendere" = "to turn on, light"
  "tenere" = "to hold, keep"
  "tornare" = "to return, go back"
  "arrivare" = "to arrive"
  "entrare" = "to enter"
  "cercare" = "to look for"
  "trovare" = "to find"
  "pensare" = "to think"
  "lasciare" = "to leave, let"
  "chiedere" = "to ask"
  "rispondere" = "to answer"
  "portare" = "to bring, carry"
  "guardare" = "to watch, look at"
  "sembrare" = "to seem"
  "chiamare" = "to call"
  "aiutare" = "to help"
  "lavorare" = "to work"
  "giocare" = "to play"
  "mangiare" = "to eat"
  "bere" = "to drink"
  "dormire" = "to sleep"
  "aprire" = "to open"
  "chiudere" = "to close"
  "scrivere" = "to write"
  "leggere" = "to read"
  "correre" = "to run"
  "cominciare" = "to begin"
  "finire" = "to finish"
  "continuare" = "to continue"
  "cambiare" = "to change"
  "passare" = "to pass, spend (time)"
  "restare" = "to stay, remain"
  "ascoltare" = "to listen"
  "aspettare" = "to wait"
  "ricordare" = "to remember"
  "dimenticare" = "to forget"
  "imparare" = "to learn"
  "insegnare" = "to teach"
  "studiare" = "to study"
  "comprare" = "to buy"
  "vendere" = "to sell"
  "pagare" = "to pay"
  "apparire" = "to appear"
  "coprire" = "to cover"
  "fermare" = "to stop"
  "lavare" = "to wash"
  "preferire" = "to prefer"
  "preparare" = "to prepare"
  "provare" = "to try, feel"
  "cadere" = "to fall"
  "riposare" = "to rest"
  "girare" = "to turn, go around"
  "incontrare" = "to meet"
  "conoscere" = "to know (a person/place)"
  "spiegare" = "to explain"
  "sognare" = "to dream"
  "permettere" = "to allow"
  "sperare" = "to hope"
  "ammettere" = "to admit"
  "riconoscere" = "to recognize"
  "sposare" = "to marry"
  "telefonare" = "to phone"
  "temere" = "to fear"
  "produrre" = "to produce"
  "togliere" = "to remove"
  "soffrire" = "to suffer"
  "tradurre" = "to translate"
  "usare" = "to use"
  "vestire" = "to dress"
  "mandare" = "to send"
  "inviare" = "to send"
  "visitare" = "to visit"
  "presentare" = "to present, introduce"
  "ottenere" = "to obtain"
  "contenere" = "to contain"
  "seguire" = "to follow"
  "servire" = "to serve"
  "diventare" = "to become"
  "mantenere" = "to maintain"
  "raccontare" = "to tell, recount"
}

# Verbs that take "essere" (not "avere") as the passato prossimo auxiliary --
# mostly motion/state verbs, mirroring French's etre-verb list. Unlike French
# (where "etre" takes "avoir": j'ai ete), Italian's "essere" takes itself as
# auxiliary (sono stato, not ho stato), so it's included here.
$essereVerbs = @("essere", "andare", "venire", "arrivare", "entrare", "uscire", "tornare", "diventare", "apparire", "cadere")

function Get-Radical($infinitive, $template) {
  $ending = $template.infinitive.'infinitive-present'.p.i
  if ($ending -is [array]) { $ending = $ending[0] }
  if ($infinitive.Length -lt $ending.Length) { return $infinitive }
  return $infinitive.Substring(0, $infinitive.Length - $ending.Length)
}

# Some forms store multiple alternative spellings as several <i> children of
# one <p> -- pick the first (the more common/standard one).
function Get-SuffixText($p) {
  if ($p.i -is [array]) { return $p.i[0] }
  return $p.i
}

function Get-TemplateFor($infinitive) {
  $templateName = $verbsByInfinitive[$infinitive]
  if (-not $templateName) { throw "Not found in verbs-it.xml: $infinitive" }
  $tmpl = $templatesByName[$templateName]
  if (-not $tmpl) { throw "Template not found for $infinitive : $templateName" }
  return $tmpl
}

function Get-Participle($infinitive) {
  $tmpl = Get-TemplateFor $infinitive
  $radical = Get-Radical $infinitive $tmpl
  $variants = $tmpl.participle.'past-participle'.p
  $masculineSingular = if ($variants -is [array]) { $variants[0] } else { $variants }
  return $radical + (Get-SuffixText $masculineSingular)
}

# Masculine plural variant (index 1 of the 4-way [masc-sing, masc-plur,
# fem-sing, fem-plur] array) -- needed for essere-verbs' noi/voi/loro passato
# prossimo, since the participle agrees in number with the subject there
# ("siamo andati", not "andato"). Avere-verbs never agree, so this is only
# ever called for essere-verbs.
function Get-ParticiplePlural($infinitive) {
  $tmpl = Get-TemplateFor $infinitive
  $radical = Get-Radical $infinitive $tmpl
  $variants = $tmpl.participle.'past-participle'.p
  $masculinePlural = if ($variants -is [array]) { $variants[1] } else { $variants }
  return $radical + (Get-SuffixText $masculinePlural)
}

function Get-Gerund($infinitive) {
  $tmpl = Get-TemplateFor $infinitive
  $radical = Get-Radical $infinitive $tmpl
  return $radical + (Get-SuffixText $tmpl.gerund.'present-gerund'.p)
}

function Get-FormsFor($infinitive) {
  $tmpl = Get-TemplateFor $infinitive
  $radical = Get-Radical $infinitive $tmpl

  $result = [ordered]@{}

  $tenseMap = [ordered]@{
    "Presente" = $tmpl.indicative.present.p
    "Imperfetto" = $tmpl.indicative.imperfect.p
    "Futuro" = $tmpl.indicative.future.p
    "Condizionale" = $tmpl.conditional.present.p
  }
  foreach ($tenseName in $tenseMap.Keys) {
    $suffixes = $tenseMap[$tenseName]
    $result[$tenseName] = [ordered]@{
      "1s" = $radical + (Get-SuffixText $suffixes[0])
      "2s" = $radical + (Get-SuffixText $suffixes[1])
      "3s" = $radical + (Get-SuffixText $suffixes[2])
      "1p" = $radical + (Get-SuffixText $suffixes[3])
      "2p" = $radical + (Get-SuffixText $suffixes[4])
      "3p" = $radical + (Get-SuffixText $suffixes[5])
    }
  }

  # Passato prossimo: auxiliary present + past participle. Singular persons
  # use the masculine singular participle; for essere-verbs the plural
  # persons need the masculine plural variant instead, since the participle
  # agrees in number with the subject there (avere-verbs never agree, so
  # this is a no-op for them -- both variants are the same participle).
  $isEssereVerb = $essereVerbs -contains $infinitive
  $participleSing = Get-Participle $infinitive
  $participlePlur = if ($isEssereVerb) { Get-ParticiplePlural $infinitive } else { $participleSing }

  $auxName = if ($isEssereVerb) { "essere" } else { "avere" }
  $auxForms = $script:AUX_PRESENT[$auxName]
  $result["Passato prossimo"] = [ordered]@{
    "1s" = "$($auxForms[0]) $participleSing"
    "2s" = "$($auxForms[1]) $participleSing"
    "3s" = "$($auxForms[2]) $participleSing"
    "1p" = "$($auxForms[3]) $participlePlur"
    "2p" = "$($auxForms[4]) $participlePlur"
    "3p" = "$($auxForms[5]) $participlePlur"
  }

  return $result
}

# Computed the same radical+suffix way as everything else, not hardcoded, so
# essere/avere's own irregular present tense stays sourced from the dataset.
function Get-PresentTense($infinitive) {
  $tmpl = Get-TemplateFor $infinitive
  $radical = Get-Radical $infinitive $tmpl
  return $tmpl.indicative.present.p | ForEach-Object { $radical + (Get-SuffixText $_) }
}

$script:AUX_PRESENT = @{
  "avere" = Get-PresentTense "avere"
  "essere" = Get-PresentTense "essere"
}

# Rank comes from LeFFI (matteo-pellegrini/LeFFI, CC BY-SA 4.0) frequency
# data -- an independent, corpus-derived (COLFIS) ranking -- rather than the
# hand-curated selection order above. The verb *selection* above is still
# hand-curated (LeFFI's frequency data doesn't change which 100 verbs are
# included, only what order they're presented in); this is exactly the
# "swap the rank source without touching selection logic" seam the rank
# field was designed for.
$leffiFreq = @{}
Import-Csv -Path (Join-Path $root "raw_verbs_it_leffi_lexemes.csv") | ForEach-Object {
  $leffiFreq[$_.lexeme_id] = [int]$_.frequency
}

$unranked = New-Object System.Collections.Generic.List[object]
foreach ($infinitive in $verbList.Keys) {
  $forms = Get-FormsFor $infinitive
  $freq = if ($leffiFreq.ContainsKey($infinitive)) { $leffiFreq[$infinitive] } else { -1 }
  $unranked.Add([pscustomobject]@{
    infinitive = $infinitive
    english = $verbList[$infinitive]
    freq = $freq
    gerund = Get-Gerund $infinitive
    participle = Get-Participle $infinitive
    forms = [ordered]@{ Indicativo = $forms }
  })
}
if (($unranked | Where-Object { $_.freq -eq -1 }).Count -gt 0) {
  Write-Warning "Not found in LeFFI, ranked last: $(($unranked | Where-Object { $_.freq -eq -1 } | ForEach-Object { $_.infinitive }) -join ', ')"
}

$verbsOut = New-Object System.Collections.Generic.List[object]
$rank = 0
foreach ($v in ($unranked | Sort-Object -Property freq -Descending)) {
  $rank++
  $verbsOut.Add([ordered]@{
    infinitive = $v.infinitive
    english = $v.english
    rank = $rank
    gerund = $v.gerund
    participle = $v.participle
    forms = $v.forms
  })
}

$result = [ordered]@{
  generatedFrom = "Verbiste (github.com/RemiCardona/verbiste, GPL-2.0) - forms computed from radical+template rules; ranked by LeFFI (matteo-pellegrini/LeFFI, CC BY-SA 4.0) frequency data"
  verbs = $verbsOut
}

$json = $result | ConvertTo-Json -Depth 10 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)

Write-Host "Wrote $($verbsOut.Count) verbs to $outPath"
