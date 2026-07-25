# Builds data/verbs.json from raw_verbs.csv for the curated starter verb list.
# Captures ALL moods/tenses found in the source for each chosen verb (not just
# the 5 simple-indicative tenses the v1 app drills) so future expansion to
# subjunctive/imperative/perfect tenses doesn't require re-processing the CSV.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $root "raw_verbs.csv"
$outPath = Join-Path $root "data\verbs.json"

$curated = @(
  "ser","estar","tener","hacer","ir","poder","decir","querer","poner","saber",
  "ver","dar","venir","salir","llegar","pasar","deber","parecer","quedar","creer",
  "hablar","llevar","dejar","seguir","encontrar","llamar","pensar","volver","tomar","conocer",
  "vivir","sentir","mirar","contar","empezar","esperar","buscar","entrar","trabajar","escribir",
  "perder","entender","pedir","recordar","comer","leer","traer",("o" + [char]0x00ED + "r"),"jugar","abrir"
)

$rows = Import-Csv -Path $csvPath -Encoding UTF8
$byVerb = [ordered]@{}

foreach ($v in $curated) { $byVerb[$v] = [ordered]@{} }

foreach ($row in $rows) {
  if (-not $byVerb.Contains($row.infinitive)) { continue }

  $moodKey = $row.mood
  if (-not $byVerb[$row.infinitive].Contains($moodKey)) {
    $byVerb[$row.infinitive][$moodKey] = [ordered]@{}
  }

  $byVerb[$row.infinitive][$moodKey][$row.tense] = [ordered]@{
    "1s" = if ($row.form_1s) { $row.form_1s } else { $null }
    "2s" = if ($row.form_2s) { $row.form_2s } else { $null }
    "3s" = if ($row.form_3s) { $row.form_3s } else { $null }
    "1p" = if ($row.form_1p) { $row.form_1p } else { $null }
    "2p" = if ($row.form_2p) { $row.form_2p } else { $null }
    "3p" = if ($row.form_3p) { $row.form_3p } else { $null }
  }
}

$verbList = New-Object System.Collections.Generic.List[object]

foreach ($v in $curated) {
  $firstRow = $rows | Where-Object { $_.infinitive -eq $v } | Select-Object -First 1
  if (-not $firstRow) {
    Write-Warning "No rows found for verb: $v"
    continue
  }
  $verbList.Add([ordered]@{
    infinitive = $v
    english = $firstRow.infinitive_english
    gerund = $firstRow.gerund
    participle = $firstRow.pastparticiple
    forms = $byVerb[$v]
  })
}

$result = [ordered]@{
  generatedFrom = "fred-jehle-spanish-verbs (jehle_verb_database.csv)"
  verbs = $verbList
}

$json = $result | ConvertTo-Json -Depth 10 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)

Write-Host "Wrote $($verbList.Count) verbs to $outPath"
