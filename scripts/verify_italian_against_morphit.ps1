# Cross-checks data/verbs.italian.json against Morph-it! (Baroni & Zanchetta,
# dual CC BY-SA 2.0 / LGPL), an independent Italian morphological lexicon --
# unrelated to both Verbiste (our source) and LeFFI, and critically, unlike
# LeFFI, Morph-it! stores real WRITTEN forms (tagged wordform+lemma+features),
# not phonetic transcription. Agreement between two independent, unrelated
# sources is real evidence of correctness.
#
# Passato prossimo isn't checked -- it's periphrastic, not a single tagged
# form in Morph-it! either.
#
# This is a read-only diagnostic. It doesn't change data/verbs.italian.json.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$morphitPath = Join-Path $root "data\morphit\morph-it_048.txt"

$ours = Get-Content -Raw -Path (Join-Path $root "data\verbs.italian.json") -Encoding UTF8 | ConvertFrom-Json

Write-Host "Loading Morph-it! (this is a ~500k-line file, converting from ISO-8859-1)..."
# Morph-it! ships as ISO-8859-1; our data and comparisons are UTF-8.
# Get-Content's -Encoding only accepts a fixed named-encoding enum in Windows
# PowerShell 5.1, not an arbitrary [System.Text.Encoding] -- read raw bytes
# and decode directly instead.
$iso88591 = [System.Text.Encoding]::GetEncoding("ISO-8859-1")
$bytes = [System.IO.File]::ReadAllBytes($morphitPath)
$raw = $iso88591.GetString($bytes) -split "`r?`n"

# Index as lemma|tag -> list of acceptable spellings (Morph-it! sometimes
# lists more than one, e.g. an apocopated variant alongside the full form).
$index = @{}
foreach ($line in $raw) {
  $parts = $line -split "`t"
  if ($parts.Count -lt 3) { continue }
  $form = $parts[0]; $lemma = $parts[1]; $tag = $parts[2]
  if ($tag -notmatch '^(VER|AUX):') { continue }
  $key = "$lemma|$tag"
  if (-not $index.ContainsKey($key)) { $index[$key] = New-Object System.Collections.Generic.List[string] }
  $index[$key].Add($form.ToLower())
}
Write-Host "Indexed $($index.Count) (lemma, tag) verb entries."

$personMap = [ordered]@{ "1s" = "1+s"; "2s" = "2+s"; "3s" = "3+s"; "1p" = "1+p"; "2p" = "2+p"; "3p" = "3+p" }
$tenseTag = [ordered]@{ "Presente" = "ind+pres"; "Imperfetto" = "ind+impf"; "Futuro" = "ind+fut"; "Condizionale" = "cond+pres" }

$totalChecked = 0
$mismatches = New-Object System.Collections.Generic.List[object]
$notInMorphit = New-Object System.Collections.Generic.List[string]

function Test-Form($infinitive, $tagSuffix, $ourForm, $cellLabel) {
  $script:key1 = "$infinitive|VER:$tagSuffix"
  $script:key2 = "$infinitive|AUX:$tagSuffix"
  $candidates = $null
  if ($index.ContainsKey($key1)) { $candidates = $index[$key1] }
  elseif ($index.ContainsKey($key2)) { $candidates = $index[$key2] }
  if (-not $candidates) { return $false }
  $script:totalChecked++
  if ($candidates -notcontains $ourForm.ToLower()) {
    $mismatches.Add([pscustomobject]@{ verb = $infinitive; cell = $cellLabel; ours = $ourForm; morphit = ($candidates -join " / ") })
  }
  return $true
}

foreach ($verb in $ours.verbs) {
  $inf = $verb.infinitive
  $anyData = $false

  foreach ($tenseName in $tenseTag.Keys) {
    $tenseForms = $verb.forms.Indicativo.$tenseName
    foreach ($personKey in $personMap.Keys) {
      $tagSuffix = "$($tenseTag[$tenseName])+$($personMap[$personKey])"
      if (Test-Form $inf $tagSuffix $tenseForms.$personKey "$tenseName $personKey") { $anyData = $true }
    }
  }

  if (Test-Form $inf "ger+pres" $verb.gerund "gerund") { $anyData = $true }
  if (Test-Form $inf "part+past+s+m" $verb.participle "participle") { $anyData = $true }

  if (-not $anyData) { $notInMorphit.Add($inf) }
}

Write-Host ""
Write-Host "=== Results ==="
Write-Host "Verbs checked: $($ours.verbs.Count)"
Write-Host "Verbs with no Morph-it! data at all: $($notInMorphit.Count) $(if ($notInMorphit.Count) { '(' + ($notInMorphit -join ', ') + ')' })"
Write-Host "Total form comparisons: $totalChecked"
Write-Host "Mismatches: $($mismatches.Count)"
if ($mismatches.Count) {
  Write-Host ""
  $mismatches | Format-Table -AutoSize
}
