[CmdletBinding()]
param(
    [string]$GameDataRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'AppData\LocalLow\Failbetter Games\Sunless Sea'),
    [string]$StateRoot = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Unterzee-Deutsch-Mod'),
    [switch]$SkipRunningGameCheck
)

$ErrorActionPreference = 'Stop'
function Get-Sha256([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash }
function Resolve-FullPath([string]$Path) { [IO.Path]::GetFullPath($Path) }
function Test-IsBelow([string]$Child, [string]$Parent) {
    $parentFull = (Resolve-FullPath $Parent).TrimEnd('\') + '\'
    (Resolve-FullPath $Child).StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)
}

if (-not $SkipRunningGameCheck -and (Get-Process -Name 'Sunless Sea' -ErrorAction SilentlyContinue)) {
    throw 'Bitte Sunless Sea vor der Deinstallation vollständig beenden.'
}

$manifestPath = Join-Path $PSScriptRoot 'package\package-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Paketmanifest fehlt. Bitte die vollständige Mod entpacken.' }
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$recordPath = Join-Path $StateRoot 'install-state.json'
$record = $null
if (Test-Path -LiteralPath $recordPath) { $record = Get-Content -Raw -Encoding UTF8 -LiteralPath $recordPath | ConvertFrom-Json }

$backupRoot = Join-Path $StateRoot 'backups'
$null = New-Item -ItemType Directory -Path $backupRoot -Force
$expectedAddon = Join-Path (Join-Path $GameDataRoot 'addon') $manifest.Name
$addon = if ($record -and $record.AddonDestination) { [string]$record.AddonDestination } else { $expectedAddon }
if ((Resolve-FullPath $addon) -ne (Resolve-FullPath $expectedAddon)) { throw 'Der gespeicherte Addon-Pfad gehört nicht zum angegebenen Benutzerverzeichnis. Abbruch.' }
if (-not (Test-IsBelow $addon $GameDataRoot)) { throw 'Unerwarteter Addon-Pfad. Abbruch.' }

if (Test-Path -LiteralPath $addon) {
    $removed = Join-Path $backupRoot ('removed-addon-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
    Move-Item -LiteralPath $addon -Destination $removed
    Write-Host "Sprachmod deaktiviert und wiederherstellbar gesichert: $removed"
} else {
    Write-Host 'Der JSON-Sprachmod ist bereits entfernt.'
}

if ($record -and $record.UI) {
    $uiDestination = [string]$record.UI.Destination
    $uiBackup = [string]$record.UI.Backup
    if (-not (Test-IsBelow $uiBackup $backupRoot)) { throw 'Unerwarteter UI-Sicherungspfad. Die DLL wird nicht verändert.' }
    if (-not (Test-Path -LiteralPath $uiBackup -PathType Leaf)) {
        Write-Warning 'Die Originalsicherung der UI-DLL fehlt. Der JSON-Sprachmod ist entfernt; die UI konnte nicht wiederhergestellt werden.'
    }
    elseif ((Get-Sha256 $uiBackup) -ne $record.UI.SourceSHA256) {
        Write-Warning 'Die Originalsicherung der UI-DLL wurde verändert. Keine DLL wird überschrieben.'
    }
    elseif (-not (Test-Path -LiteralPath $uiDestination -PathType Leaf)) {
        Write-Warning 'Die installierte Spiel-DLL wurde nicht gefunden. Die Originalsicherung bleibt erhalten.'
    }
    else {
        $currentHash = Get-Sha256 $uiDestination
        if ($currentHash -eq $record.UI.SourceSHA256) {
            Write-Host 'Die originale UI-DLL ist bereits wiederhergestellt.'
        }
        elseif ($currentHash -eq $record.UI.PatchedSHA256) {
            Copy-Item -LiteralPath $uiDestination -Destination (Join-Path $backupRoot ('removed-ui-patch-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '.dll'))
            Copy-Item -LiteralPath $uiBackup -Destination $uiDestination
            if ((Get-Sha256 $uiDestination) -ne $record.UI.SourceSHA256) { throw 'Wiederherstellung der Original-DLL fehlgeschlagen.' }
            Write-Host 'Originale Spieloberfläche wiederhergestellt.'
        }
        else {
            Write-Warning 'Die Spiel-DLL wurde seit der Installation geändert. Sie wird nicht mit einer älteren Fassung überschrieben.'
        }
    }
}

if ($record -and $record.Core) {
    $coreDestination = [string]$record.Core.Destination
    $coreBackup = [string]$record.Core.Backup
    if (-not (Test-IsBelow $coreBackup $backupRoot)) { throw 'Unerwarteter Core-Sicherungspfad. Die DLL wird nicht verändert.' }
    if (-not (Test-Path -LiteralPath $coreBackup -PathType Leaf)) {
        Write-Warning 'Die Originalsicherung der Core-DLL fehlt. Die generischen Ergebnismeldungen konnten nicht wiederhergestellt werden.'
    }
    elseif ((Get-Sha256 $coreBackup) -ne $record.Core.SourceSHA256) {
        Write-Warning 'Die Originalsicherung der Core-DLL wurde verändert. Keine DLL wird überschrieben.'
    }
    elseif (-not (Test-Path -LiteralPath $coreDestination -PathType Leaf)) {
        Write-Warning 'Die installierte Core-DLL wurde nicht gefunden. Die Originalsicherung bleibt erhalten.'
    }
    else {
        $coreCurrentHash = Get-Sha256 $coreDestination
        if ($coreCurrentHash -eq $record.Core.SourceSHA256) { Write-Host 'Die originale Core-DLL ist bereits wiederhergestellt.' }
        elseif ($coreCurrentHash -eq $record.Core.PatchedSHA256) {
            Copy-Item -LiteralPath $coreDestination -Destination (Join-Path $backupRoot ('removed-core-patch-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '.dll'))
            Copy-Item -LiteralPath $coreBackup -Destination $coreDestination
            if ((Get-Sha256 $coreDestination) -ne $record.Core.SourceSHA256) { throw 'Wiederherstellung der originalen Core-DLL fehlgeschlagen.' }
            Write-Host 'Originale generische Qualitätsmeldungen wiederhergestellt.'
        }
        else { Write-Warning 'Die Core-DLL wurde seit der Installation geändert. Sie wird nicht mit einer älteren Fassung überschrieben.' }
    }
}

if ($record -and $record.Resources) {
    $resourceDestination = [string]$record.Resources.Destination
    $resourceBackup = [string]$record.Resources.Backup
    $resourceGameRoot = [string]$record.Resources.GameRoot
    if (-not (Test-IsBelow $resourceBackup $backupRoot)) { throw 'Unerwarteter Ressourcen-Sicherungspfad. Die Spieldatei wird nicht verändert.' }
    if (-not $resourceGameRoot -or -not (Test-IsBelow $resourceDestination $resourceGameRoot)) { throw 'Unerwarteter Ressourcen-Zielpfad. Die Spieldatei wird nicht verändert.' }
    if (-not (Test-Path -LiteralPath $resourceBackup -PathType Leaf)) {
        Write-Warning 'Die Originalsicherung von resources.assets fehlt. Die Ressourcendatei konnte nicht wiederhergestellt werden.'
    }
    elseif ((Get-Sha256 $resourceBackup) -ne $record.Resources.SourceSHA256) {
        Write-Warning 'Die Originalsicherung von resources.assets wurde verändert. Keine Spieldatei wird überschrieben.'
    }
    elseif (-not (Test-Path -LiteralPath $resourceDestination -PathType Leaf)) {
        Write-Warning 'Die installierte resources.assets wurde nicht gefunden. Die Originalsicherung bleibt erhalten.'
    }
    else {
        $resourceCurrentHash = Get-Sha256 $resourceDestination
        if ($resourceCurrentHash -eq $record.Resources.SourceSHA256) {
            Write-Host 'Die originale Oberflächen-Ressource ist bereits wiederhergestellt.'
        }
        elseif ($resourceCurrentHash -eq $record.Resources.PatchedSHA256) {
            Copy-Item -LiteralPath $resourceDestination -Destination (Join-Path $backupRoot ('removed-resources-patch-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '.assets'))
            Copy-Item -LiteralPath $resourceBackup -Destination $resourceDestination
            if ((Get-Sha256 $resourceDestination) -ne $record.Resources.SourceSHA256) { throw 'Wiederherstellung der originalen Oberflächen-Ressource fehlgeschlagen.' }
            Write-Host 'Originale Oberflächen-Ressource wiederhergestellt.'
        }
        else {
            Write-Warning 'resources.assets wurde seit der Installation geändert. Sie wird nicht mit einer älteren Fassung überschrieben.'
        }
    }
}

if ($record) {
    $record | Add-Member -NotePropertyName UninstalledAt -NotePropertyValue ([DateTimeOffset]::Now.ToString('o')) -Force
    $record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $recordPath -Encoding UTF8
}
Write-Host 'Deinstallation abgeschlossen. Spielstände wurden nicht gelesen, kopiert oder gelöscht.'
