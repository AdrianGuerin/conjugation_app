# Trims data/verbs.json down to a small sample (for the standalone share
# build): fewer verbs, and only the mood/tenses the app actually drills
# (dropping subjunctive/imperative/perfect tenses that v1 never uses).

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$fullPath = Join-Path $root "data\verbs.json"
$outPath = Join-Path $root "data\verbs.sample.json"

$sample = @("ser","estar","tener","hacer","ir","poder","decir","querer","hablar","comer","vivir","ver")
$activeTenses = @("Presente",("Pret" + [char]0x00E9 + "rito"),"Imperfecto","Futuro","Condicional")

$full = Get-Content -Raw -Path $fullPath -Encoding UTF8 | ConvertFrom-Json

$trimmed = New-Object System.Collections.Generic.List[object]
foreach ($infinitive in $sample) {
  $verb = $full.verbs | Where-Object { $_.infinitive -eq $infinitive }
  if (-not $verb) {
    Write-Warning "Not found in full dataset: $infinitive"
    continue
  }
  $indicativo = $verb.forms.Indicativo
  $trimmedForms = [ordered]@{}
  foreach ($t in $activeTenses) {
    $trimmedForms[$t] = $indicativo.$t
  }
  $trimmed.Add([ordered]@{
    infinitive = $verb.infinitive
    english = $verb.english
    gerund = $verb.gerund
    participle = $verb.participle
    forms = [ordered]@{ Indicativo = $trimmedForms }
  })
}

$result = [ordered]@{
  generatedFrom = "fred-jehle-spanish-verbs (sample)"
  verbs = $trimmed
}

$json = $result | ConvertTo-Json -Depth 10 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)

Write-Host "Wrote $($trimmed.Count) verbs to $outPath"
