# Builds data/verbs.french.json from the Verbiste-derived conjugation-fr /
# verbs-fr datasets (raw_verbs_fr_*.json, downloaded from
# github.com/gauthier-th/conjugation-fr). That dataset is rule-based: each
# verb points at a "template" of suffixes relative to a radical (infinitive
# minus the template's own ending), so forms are computed rather than looked
# up verbatim -- this is far less error-prone than hand-transcribing ~1500
# conjugated forms.
#
# Passe compose is not itself a template entry (it's a compound tense), so
# it's built here as [auxiliary present tense] + [masculine singular past
# participle]. Third person is drilled as bare "il"/"ils" rather than
# "il / elle" etc., specifically because the stored participle is masculine
# and would be wrong for "elle" in etre-verbs (e.g. "elle est allee", not
# "alle") -- offering the ambiguous label would be actively misleading here.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$outPath = Join-Path $root "data\verbs.french.json"

$verbsFr = Get-Content -Raw -Path (Join-Path $root "raw_verbs_fr_list.json") -Encoding UTF8 | ConvertFrom-Json
$conjFr = Get-Content -Raw -Path (Join-Path $root "raw_verbs_fr_templates.json") -Encoding UTF8 | ConvertFrom-Json

function CH([int]$code) { return [string][char]$code }

# Verbs with accents, built via char codes to dodge the PowerShell 5.1 /
# non-BOM-UTF8 mis-decoding issue seen earlier in this project with literal
# accented characters inside .ps1 source.
$etre = (CH 0x00EA) + "tre"
$connaitre = "conna" + (CH 0x00EE) + "tre"
$reussir = "r" + (CH 0x00E9) + "ussir"
$reflechir = "r" + (CH 0x00E9) + "fl" + (CH 0x00E9) + "chir"
$repondre = "r" + (CH 0x00E9) + "pondre"

$verbList = [ordered]@{
  $etre = "to be"
  "avoir" = "to have"
  "aller" = "to go"
  "faire" = "to do, make"
  "pouvoir" = "to be able to, can"
  "vouloir" = "to want"
  "devoir" = "to have to, must"
  "savoir" = "to know (a fact)"
  "venir" = "to come"
  "voir" = "to see"
  "prendre" = "to take"
  "dire" = "to say, tell"
  "mettre" = "to put, place"
  $connaitre = "to know (a person/place)"
  "croire" = "to believe"
  "tenir" = "to hold"
  "sortir" = "to go out, leave"
  "partir" = "to leave, depart"
  "sentir" = "to feel, smell"
  "boire" = "to drink"
  "finir" = "to finish"
  "choisir" = "to choose"
  $reussir = "to succeed"
  "remplir" = "to fill"
  $reflechir = "to think, reflect"
  "attendre" = "to wait for"
  "entendre" = "to hear"
  $repondre = "to answer"
  "vendre" = "to sell"
  "perdre" = "to lose"
  "parler" = "to speak"
  "aimer" = "to like, love"
  "chercher" = "to look for"
  "penser" = "to think"
  "trouver" = "to find"
  "donner" = "to give"
  "passer" = "to pass, spend (time)"
  "arriver" = "to arrive"
  "rester" = "to stay, remain"
  "demander" = "to ask for"
  "laisser" = "to let, leave"
  "entrer" = "to enter"
  "regarder" = "to watch, look at"
  "aider" = "to help"
  "jouer" = "to play"
  "montrer" = "to show"
  "continuer" = "to continue"
  "changer" = "to change"
  "tomber" = "to fall"
  "commencer" = "to begin"
}

$etreVerbs = @("aller", "venir", "entrer", "sortir", "partir", "arriver", "rester", "tomber")

function Get-Radical($infinitive, $template) {
  $ending = $template.infinitive.'infinitive-present'.i
  if ($infinitive.Length -lt $ending.Length) { return $infinitive }
  return $infinitive.Substring(0, $infinitive.Length - $ending.Length)
}

# A few forms (e.g. pouvoir's "je peux"/"je puis") store two valid
# alternatives as an array rather than a single string. Pick the first
# (the more common/standard one) rather than let PowerShell silently
# string-join the array into garbage on concatenation.
function Get-SuffixText($suffixObj) {
  if ($suffixObj.i -is [array]) { return $suffixObj.i[0] }
  return $suffixObj.i
}

function Get-Participle($infinitive) {
  $entry = $verbsFr.$infinitive
  $tmpl = $conjFr.($entry.t)
  $radical = Get-Radical $infinitive $tmpl
  $participleField = $tmpl.participle.'past-participle'
  $participleSuffix = if ($participleField -is [array]) { Get-SuffixText $participleField[0] } else { Get-SuffixText $participleField }
  return $radical + $participleSuffix
}

function Get-PresentParticiple($infinitive) {
  $entry = $verbsFr.$infinitive
  $tmpl = $conjFr.($entry.t)
  $radical = Get-Radical $infinitive $tmpl
  return $radical + (Get-SuffixText $tmpl.participle.'present-participle')
}

function Get-FormsFor($infinitive) {
  $entry = $verbsFr.$infinitive
  if (-not $entry) { throw "Not found in verbs-fr.json: $infinitive" }
  $tmpl = $conjFr.($entry.t)
  if (-not $tmpl) { throw "Template not found for $infinitive : $($entry.t)" }
  $radical = Get-Radical $infinitive $tmpl

  $result = [ordered]@{}

  $tenseMap = [ordered]@{
    ((CH 0x0050) + "r" + (CH 0x00E9) + "sent") = $tmpl.indicative.present
    "Imparfait" = $tmpl.indicative.imperfect
    "Futur" = $tmpl.indicative.future
    "Conditionnel" = $tmpl.conditional.present
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

  # Passe compose: auxiliary present + masculine singular past participle.
  $participleField = $tmpl.participle.'past-participle'
  $participleSuffix = if ($participleField -is [array]) { Get-SuffixText $participleField[0] } else { Get-SuffixText $participleField }
  $participle = $radical + $participleSuffix

  $auxName = if ($etreVerbs -contains $infinitive) { "etre" } else { "avoir" }
  $auxForms = $script:AUX_PRESENT[$auxName]
  $passeComposeKey = "Pass" + (CH 0x00E9) + " compos" + (CH 0x00E9)
  $result[$passeComposeKey] = [ordered]@{
    "1s" = "$($auxForms[0]) $participle"
    "2s" = "$($auxForms[1]) $participle"
    "3s" = "$($auxForms[2]) $participle"
    "1p" = "$($auxForms[3]) $participle"
    "2p" = "$($auxForms[4]) $participle"
    "3p" = "$($auxForms[5]) $participle"
  }

  return $result
}

# Computed the same radical+suffix way as everything else, not hardcoded,
# so avoir/etre's own irregular present tense stays sourced from the dataset.
function Get-PresentTense($infinitive) {
  $entry = $verbsFr.$infinitive
  $tmpl = $conjFr.($entry.t)
  $radical = Get-Radical $infinitive $tmpl
  return $tmpl.indicative.present | ForEach-Object { $radical + (Get-SuffixText $_) }
}

$script:AUX_PRESENT = @{
  "avoir" = Get-PresentTense "avoir"
  "etre" = Get-PresentTense $etre
}

$verbsOut = New-Object System.Collections.Generic.List[object]
foreach ($infinitive in $verbList.Keys) {
  $forms = Get-FormsFor $infinitive
  $verbsOut.Add([ordered]@{
    infinitive = $infinitive
    english = $verbList[$infinitive]
    gerund = Get-PresentParticiple $infinitive
    participle = Get-Participle $infinitive
    forms = [ordered]@{ Indicatif = $forms }
  })
}

$result = [ordered]@{
  generatedFrom = "conjugation-fr (Verbiste-derived, GPL-2.0) - forms computed from radical+template rules"
  verbs = $verbsOut
}

$json = $result | ConvertTo-Json -Depth 10 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)

Write-Host "Wrote $($verbsOut.Count) verbs to $outPath"
