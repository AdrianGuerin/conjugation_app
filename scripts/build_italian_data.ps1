# Builds data/verbs.italian.json from Morph-it! (Baroni & Zanchetta, dual
# CC BY-SA 2.0 / LGPL), a comprehensive Italian morphological lexicon of
# tagged wordforms -- data/morphit/morph-it_048.txt, 505k entries.
#
# Unlike the original version of this script (Verbiste radical+template
# computation), forms here are looked up **verbatim**, the same architecture
# Spanish's build_data.ps1 already uses successfully. This switch happened
# after a verification pass against Morph-it found real bugs in the computed
# approach: several verbs (chiedere, chiudere, coprire, produrre, tradurre)
# appear TWICE in Verbiste's source XML with two different, conflicting
# templates, and the old script's naive lookup silently kept whichever
# came last in the file -- with no way to know it picked wrong without an
# external check like this one. See NOTES.md for the full account.
#
# Morph-it! isn't perfect either: it has at least one confirmed tagging bug
# (duplicates "prenderà" under both 1s and 3s future, missing "prenderò"
# entirely). $overrides below hand-corrects the specific cells this
# verification pass found wrong; Get-FormsFor also sanity-checks that 1st
# and 3rd person singular are never identical (linguistically impossible in
# any Italian tense), which is exactly the shape of that bug, so a future
# re-run catches new instances of it rather than silently trusting them.
#
# Passato prossimo isn't in Morph-it as a single form either (it's
# periphrastic) -- built the same way as before: [auxiliary present tense]
# + [past participle], both now looked up verbatim rather than computed.
# Third person is still drilled as bare "lui" (not "lui / lei"), since the
# looked-up participle is masculine and would be wrong for "lei" on
# essere-verbs.
#
# Rank still comes from LeFFI frequency data (unaffected by this change --
# see build_italian_data.ps1's git history for that seam).

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$outPath = Join-Path $root "data\verbs.italian.json"
$morphitPath = Join-Path $root "data\morphit\morph-it_048.txt"

Write-Host "Loading Morph-it! (large file, decoding from ISO-8859-1)..."
$iso88591 = [System.Text.Encoding]::GetEncoding("ISO-8859-1")
$bytes = [System.IO.File]::ReadAllBytes($morphitPath)
$lines = $iso88591.GetString($bytes) -split "`r?`n"

# lemma|tag -> candidate spellings. Morph-it! sometimes lists more than one
# for a cell (e.g. an apocopated variant alongside the standard form, like
# "dan" beside "danno") -- Get-MorphitForm below picks the longest, which
# matched the standard/modern form in every case checked during verification
# (danno>dan, chiedono>chiedon, vorranno>vorran, berrebbero>berrebber).
$index = @{}
foreach ($line in $lines) {
  $parts = $line -split "`t"
  if ($parts.Count -lt 3) { continue }
  $form = $parts[0]; $lemma = $parts[1]; $tag = $parts[2]
  if ($tag -notmatch '^(VER|AUX):(.+)$') { continue }
  $key = "$lemma|$($matches[2])"
  if (-not $index.ContainsKey($key)) { $index[$key] = New-Object System.Collections.Generic.List[string] }
  $index[$key].Add($form)
}
Write-Host "Indexed $($index.Count) (lemma, tag) verb entries."

# Cells this verification pass found Morph-it! itself gets wrong (see header
# comment). All four are regular -ere verbs where the standard pattern
# (infinitive minus final "e", plus "-o with a grave accent") is unambiguous.
# Built via char code, not a literal accented character -- see this
# project's other build_*.ps1 scripts for why (PowerShell 5.1 misreads
# literal accented characters in non-BOM-UTF8 .ps1 source).
$o_grave = [string][char]0x00F2
$overrides = @{
  "prendere|ind+fut+1+s" = "prender$o_grave"
  "rispondere|ind+fut+1+s" = "risponder$o_grave"
  "temere|ind+fut+1+s" = "temer$o_grave"
  "accendere|ind+fut+1+s" = "accender$o_grave"
}

function Get-MorphitForm($infinitive, $tagSuffix) {
  $overrideKey = "$infinitive|$tagSuffix"
  if ($overrides.ContainsKey($overrideKey)) { return $overrides[$overrideKey] }
  $key = "$infinitive|$tagSuffix"
  if (-not $index.ContainsKey($key)) { throw "Not found in Morph-it!: $infinitive ($tagSuffix)" }
  $candidates = $index[$key]
  return ($candidates | Sort-Object Length -Descending | Select-Object -First 1)
}

$personMap = [ordered]@{ "1s" = "1+s"; "2s" = "2+s"; "3s" = "3+s"; "1p" = "1+p"; "2p" = "2+p"; "3p" = "3+p" }
$tenseTag = [ordered]@{ "Presente" = "ind+pres"; "Imperfetto" = "ind+impf"; "Futuro" = "ind+fut"; "Condizionale" = "cond+pres" }

function Get-Participle($infinitive) { return Get-MorphitForm $infinitive "part+past+s+m" }
function Get-ParticiplePlural($infinitive) { return Get-MorphitForm $infinitive "part+past+p+m" }
function Get-Gerund($infinitive) { return Get-MorphitForm $infinitive "ger+pres" }

function Get-FormsFor($infinitive) {
  $result = [ordered]@{}
  foreach ($tenseName in $tenseTag.Keys) {
    $tenseResult = [ordered]@{}
    foreach ($personKey in $personMap.Keys) {
      $tenseResult[$personKey] = Get-MorphitForm $infinitive "$($tenseTag[$tenseName])+$($personMap[$personKey])"
    }
    # 1st and 3rd person singular are never identical in any Italian tense --
    # if they are, the source data has a bug (this is exactly the shape of
    # Morph-it!'s own confirmed prendere/rispondere/temere/accendere bug).
    if ($tenseResult["1s"] -eq $tenseResult["3s"]) {
      Write-Warning "$infinitive $tenseName`: 1s and 3s are identical ('$($tenseResult['1s'])') -- likely a source-data bug, needs a manual override."
    }
    $result[$tenseName] = $tenseResult
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
    "1s" = "$($auxForms['1s']) $participleSing"
    "2s" = "$($auxForms['2s']) $participleSing"
    "3s" = "$($auxForms['3s']) $participleSing"
    "1p" = "$($auxForms['1p']) $participlePlur"
    "2p" = "$($auxForms['2p']) $participlePlur"
    "3p" = "$($auxForms['3p']) $participlePlur"
  }

  return $result
}

# Ordered most-to-least common (hand-curated, not corpus-derived -- see
# README). Verb *selection* is unrelated to the rank field (see below) --
# this list only decides which 100 verbs are included. Several entries here
# stand in for common verbs the Verbiste-XML-era pipeline didn't have active
# (see NOTES.md) -- e.g. "accendere" instead of "rimanere". Morph-it! *does*
# have those gap verbs (nascere, morire, rimanere...) available now that
# forms are looked up rather than computed, so revisiting this selection is
# a real, separate option -- not done here to keep this change scoped to the
# lookup-vs-computed switch.
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
# auxiliary (sono stato, not ho stato), so it's included here. Not derivable
# from Morph-it! (it doesn't tag which auxiliary a verb takes), still
# hand-maintained.
$essereVerbs = @("essere", "andare", "venire", "arrivare", "entrare", "uscire", "tornare", "diventare", "apparire", "cadere")

$script:AUX_PRESENT = @{
  "avere" = [ordered]@{}
  "essere" = [ordered]@{}
}
foreach ($auxName in @("avere", "essere")) {
  foreach ($personKey in $personMap.Keys) {
    $script:AUX_PRESENT[$auxName][$personKey] = Get-MorphitForm $auxName "ind+pres+$($personMap[$personKey])"
  }
}

# Rank comes from LeFFI (matteo-pellegrini/LeFFI, CC BY-SA 4.0) frequency
# data -- an independent, corpus-derived (COLFIS) ranking -- rather than the
# hand-curated selection order above. This is unaffected by the lookup-vs-
# computed switch above; it was already using this seam.
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
  generatedFrom = "Morph-it! (Baroni & Zanchetta, dual CC BY-SA 2.0 / LGPL) - forms looked up verbatim; ranked by LeFFI (matteo-pellegrini/LeFFI, CC BY-SA 4.0) frequency data"
  verbs = $verbsOut
}

$json = $result | ConvertTo-Json -Depth 10 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)

Write-Host "Wrote $($verbsOut.Count) verbs to $outPath"
