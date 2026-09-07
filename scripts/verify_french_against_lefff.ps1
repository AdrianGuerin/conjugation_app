# Cross-checks data/verbs.french.json against Lefff (Lexique des Formes
# Flechies du Francais, Benoit Sagot / INRIA), via the `french-verbs-lefff`
# npm package's derived conjugations.json (LGPL-LR). Unlike LeFFI's Italian
# data, this stores real WRITTEN forms verbatim, so it's directly comparable
# to our data -- no phonetic-vs-orthographic mismatch like the LeFFI attempt.
#
# Passe compose isn't checked -- it's periphrastic, not a single Lefff cell
# either (same as both Spanish's pretérito-vs-compound and Italian's passato
# prossimo situation).
#
# This is a read-only diagnostic. It doesn't change data/verbs.french.json.
#
# NOTE: Get-Content -Raw on this JSON file WITHOUT an explicit -Encoding
# double-encodes accented characters in Windows PowerShell 5.1 (its default
# encoding detection guessed wrong) -- "être" silently became "Ãªtre".
# -Encoding UTF8 is required, not optional, on both file reads below.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$ours = Get-Content -Raw -Encoding UTF8 -Path (Join-Path $root "data\verbs.french.json") | ConvertFrom-Json
$lefff = Get-Content -Raw -Encoding UTF8 -Path (Join-Path $root "raw_verbs_fr_lefff.json") | ConvertFrom-Json

# Person order in Lefff's 6-element arrays (1s,2s,3s,1p,2p,3p) matches our
# own storage order directly -- no remapping needed.
$personIndex = [ordered]@{ "1s" = 0; "2s" = 1; "3s" = 2; "1p" = 3; "2p" = 4; "3p" = 5 }
# Built via char code, not a literal accented character -- see this
# project's other scripts for why (PowerShell 5.1 misreads literal accented
# characters in non-BOM-UTF8 .ps1 source; this bit this very script on its
# first run, silently turning every "Présent" comparison into a false
# blank-vs-value "mismatch").
$e_acute = [string][char]0x00E9
$tenseCode = [ordered]@{ "Pr$($e_acute)sent" = "P"; "Imparfait" = "I"; "Futur" = "F"; "Conditionnel" = "C" }

$totalChecked = 0
$mismatches = New-Object System.Collections.Generic.List[object]
$notInLefff = New-Object System.Collections.Generic.List[string]

foreach ($verb in $ours.verbs) {
  $inf = $verb.infinitive
  $entry = $lefff.$inf
  if (-not $entry) { $notInLefff.Add($inf); continue }

  foreach ($tenseName in $tenseCode.Keys) {
    $code = $tenseCode[$tenseName]
    $lefffForms = $entry.$code
    if (-not $lefffForms) { continue }
    $ourForms = $verb.forms.Indicatif.$tenseName
    foreach ($personKey in $personIndex.Keys) {
      $totalChecked++
      $ourForm = $ourForms.$personKey
      $lefffForm = $lefffForms[$personIndex[$personKey]]
      if ($ourForm -ne $lefffForm) {
        $mismatches.Add([pscustomobject]@{ verb = $inf; cell = "$tenseName $personKey"; ours = $ourForm; lefff = $lefffForm })
      }
    }
  }

  # Gerund (drilled as "Participe présent" -- see NOTES.md on why)
  if ($entry.G) {
    $totalChecked++
    if ($verb.gerund -ne $entry.G[0]) {
      $mismatches.Add([pscustomobject]@{ verb = $inf; cell = "gerund"; ours = $verb.gerund; lefff = $entry.G[0] })
    }
  }

  # Participle (masculine singular, matching what we store)
  if ($entry.K) {
    $totalChecked++
    if ($verb.participle -ne $entry.K[0]) {
      $mismatches.Add([pscustomobject]@{ verb = $inf; cell = "participle"; ours = $verb.participle; lefff = $entry.K[0] })
    }
  }
}

Write-Host ""
Write-Host "=== Results ==="
Write-Host "Verbs checked: $($ours.verbs.Count)"
Write-Host "Verbs with no Lefff entry at all: $($notInLefff.Count) $(if ($notInLefff.Count) { '(' + ($notInLefff -join ', ') + ')' })"
Write-Host "Total form comparisons: $totalChecked"
Write-Host "Mismatches: $($mismatches.Count)"
if ($mismatches.Count) {
  Write-Host ""
  $mismatches | Format-Table -AutoSize
}
