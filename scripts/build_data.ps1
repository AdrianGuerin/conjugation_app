# Builds data/verbs.json from raw_verbs.csv for the curated starter verb list.
# Captures ALL moods/tenses found in the source for each chosen verb (not just
# the 5 simple-indicative tenses the v1 app drills) so future expansion to
# subjunctive/imperative/perfect tenses doesn't require re-processing the CSV.

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$csvPath = Join-Path $root "raw_verbs.csv"
$outPath = Join-Path $root "data\verbs.json"
$freqPath = Join-Path $root "raw_verbs_es_freq.txt"

# Verb *selection* (which 100 verbs) is still hand-curated from general
# knowledge -- see README. Rank is not: it comes from summing each verb's
# actual inflected forms' frequencies in hermitdave/FrequencyWords
# (OpenSubtitles-derived, CC BY-SA 4.0). That list is raw wordform frequency,
# not lemma frequency (unlike Italian's LeFFI/COLFIS source, which is a
# proper lemma lexicon) -- looking up only the bare infinitive would
# understate verbs whose conjugated forms dominate usage far more than the
# infinitive itself does, so every stored form (all moods/tenses this script
# captures, not just the 5 the app drills, plus gerund/participle) is summed
# instead. See NOTES.md.
$curated = @(
  "ser","estar","tener","hacer","ir","poder","decir","querer","poner","saber",
  "ver","dar","venir","salir","llegar","pasar","deber","parecer","quedar","creer",
  "hablar","llevar","dejar","seguir","encontrar","llamar","pensar","volver","tomar","conocer",
  "vivir","sentir","mirar","contar","empezar","esperar","buscar","entrar","trabajar","escribir",
  "perder","entender","pedir","recordar","comer","leer","traer",("o" + [char]0x00ED + "r"),"jugar","abrir",
  "necesitar","gustar","acabar","morir","nacer","cerrar","mostrar","aparecer","terminar","comenzar",
  "servir","sacar","dormir","olvidar","aprender","subir","bajar","romper","correr","andar",
  "cortar","tirar","enviar","tocar","ganar","cumplir","ofrecer","suponer","faltar","importar",
  "resultar","presentar","crear","establecer","incluir","continuar","permitir","lograr","explicar","conseguir",
  "formar","tratar","producir","ocurrir","significar","convertir","mantener","desarrollar","utilizar",("a" + [char]0x00F1 + "adir")
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

# Recursively collects every leaf string value out of the nested
# mood -> tense -> person structure, so every inflected form gets counted
# (not just the 5 tenses the app actively drills).
function Get-AllStrings($obj) {
  $result = New-Object System.Collections.Generic.List[string]
  if ($obj -is [string]) {
    if ($obj) { $result.Add($obj) }
  } elseif ($obj -is [System.Collections.IDictionary]) {
    # ",$result" prevents PowerShell from unwrapping a single-element list
    # return value back into a bare string (a well-known footgun here).
    foreach ($v in $obj.Values) { $result.AddRange((Get-AllStrings $v)) }
  }
  return ,$result
}

$freqTable = @{}
Get-Content -Encoding UTF8 -Path $freqPath | ForEach-Object {
  $parts = $_ -split ' '
  if ($parts.Count -eq 2) { $freqTable[$parts[0]] = [long]$parts[1] }
}

function Get-FrequencySum($forms) {
  $total = 0L
  foreach ($f in $forms) {
    $key = $f.ToLower()
    if ($freqTable.ContainsKey($key)) { $total += $freqTable[$key] }
  }
  return $total
}

$unranked = New-Object System.Collections.Generic.List[object]

foreach ($v in $curated) {
  $firstRow = $rows | Where-Object { $_.infinitive -eq $v } | Select-Object -First 1
  if (-not $firstRow) {
    Write-Warning "No rows found for verb: $v"
    continue
  }
  $allForms = (Get-AllStrings $byVerb[$v])
  $allForms.Add($v)
  $allForms.Add($firstRow.gerund)
  $allForms.Add($firstRow.pastparticiple)
  $unranked.Add([pscustomobject]@{
    infinitive = $v
    english = $firstRow.infinitive_english
    freq = Get-FrequencySum $allForms
    gerund = $firstRow.gerund
    participle = $firstRow.pastparticiple
    forms = $byVerb[$v]
  })
}
if (($unranked | Where-Object { $_.freq -eq 0 }).Count -gt 0) {
  Write-Warning "Zero frequency (no forms found in OpenSubtitles list), ranked last: $(($unranked | Where-Object { $_.freq -eq 0 } | ForEach-Object { $_.infinitive }) -join ', ')"
}

$verbList = New-Object System.Collections.Generic.List[object]
$rank = 0
foreach ($v in ($unranked | Sort-Object -Property freq -Descending)) {
  $rank++
  $verbList.Add([ordered]@{
    infinitive = $v.infinitive
    english = $v.english
    rank = $rank
    gerund = $v.gerund
    participle = $v.participle
    forms = $v.forms
  })
}

$result = [ordered]@{
  generatedFrom = "fred-jehle-spanish-verbs (jehle_verb_database.csv); ranked by summed inflected-form frequency from hermitdave/FrequencyWords (OpenSubtitles-derived, CC BY-SA 4.0)"
  verbs = $verbList
}

$json = $result | ConvertTo-Json -Depth 10 -Compress
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, $json, $utf8NoBom)

Write-Host "Wrote $($verbList.Count) verbs to $outPath"
