[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InputPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$SpecPath
)

$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) { throw "Ressourcendatei fehlt: $InputPath" }
if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) { throw "Ressourcen-Patchspezifikation fehlt: $SpecPath" }

$spec = Get-Content -Raw -Encoding UTF8 -LiteralPath $SpecPath | ConvertFrom-Json
if ([int]$spec.schemaVersion -ne 1) { throw "Nicht unterstuetzte Ressourcen-Patchspezifikation: $($spec.schemaVersion)" }
if ([string]$spec.mode -cne 'exact-offset-equal-byte-length') { throw "Unsicherer Ressourcen-Patchmodus: $($spec.mode)" }
if ([string]$spec.encoding -cne 'ASCII') { throw "Nicht unterstuetzte Ressourcen-Kodierung: $($spec.encoding)" }

$sourceHash = Get-Sha256 $InputPath
if ($sourceHash -cne [string]$spec.sourceSHA256) {
    throw "Die Ressourcendatei gehoert nicht zur unterstuetzten Spielversion (SHA256 $sourceHash)."
}
$bytes = [IO.File]::ReadAllBytes($InputPath)
if ($bytes.LongLength -ne [long]$spec.sourceLength) {
    throw "Unerwartete Laenge der Ressourcendatei: $($bytes.LongLength) statt $($spec.sourceLength)."
}

$ascii = [Text.Encoding]::ASCII
$ranges = New-Object 'System.Collections.Generic.List[object]'
foreach ($patch in @($spec.patches)) {
    $offset = [long]$patch.offset
    $length = [int]$patch.bytes
    $from = $ascii.GetBytes([string]$patch.from)
    $to = $ascii.GetBytes([string]$patch.to)
    if ($from.Length -ne $length -or $to.Length -ne $length) {
        throw "Patch bei Offset $offset ist nicht laengengleich."
    }
    if ($offset -lt 0 -or ($offset + $length) -gt $bytes.LongLength) {
        throw "Patch bei Offset $offset liegt ausserhalb der Datei."
    }
    foreach ($range in $ranges) {
        if ($offset -lt $range.End -and ($offset + $length) -gt $range.Start) {
            throw "Ueberlappende Ressourcen-Patches bei Offset $offset."
        }
    }
    for ($i = 0; $i -lt $length; $i++) {
        if ($bytes[$offset + $i] -ne $from[$i]) {
            throw "Quelldaten stimmen bei Offset $($offset + $i) nicht mit der Spezifikation ueberein."
        }
    }
    $ranges.Add([pscustomobject]@{ Start = $offset; End = ($offset + $length) })
    [Array]::Copy($to, 0, $bytes, $offset, $length)
}

$outputParent = Split-Path -Parent $OutputPath
if ($outputParent) { $null = New-Item -ItemType Directory -Path $outputParent -Force }
[IO.File]::WriteAllBytes($OutputPath, $bytes)
if ((Get-Item -LiteralPath $OutputPath).Length -ne [long]$spec.sourceLength) {
    throw 'Der Ressourcen-Patch hat die Dateilaenge veraendert.'
}
$resultHash = Get-Sha256 $OutputPath
if ($resultHash -cne [string]$spec.patchedSHA256) {
    throw "Unerwartete Pruefsumme nach dem Ressourcen-Patch: $resultHash"
}

[pscustomobject]@{
    Result = 'PASS'
    Patches = @($spec.patches).Count
    SourceSHA256 = $sourceHash
    PatchedSHA256 = $resultHash
    OutputPath = [IO.Path]::GetFullPath($OutputPath)
}
