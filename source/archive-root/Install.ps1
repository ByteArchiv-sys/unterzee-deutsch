[CmdletBinding()]
param(
    [string]$GameRoot,
    [string]$GameDataRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'AppData\LocalLow\Failbetter Games\Sunless Sea'),
    [string]$StateRoot = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Unterzee-Deutsch-Mod'),
    [switch]$NoUI,
    [switch]$NonInteractive,
    [switch]$SkipRunningGameCheck
)

$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash }
function Get-JsonProperties($Object) { @($Object.PSObject.Properties) }
function Resolve-FullPath([string]$Path) { [IO.Path]::GetFullPath($Path) }
function Test-IsBelow([string]$Child, [string]$Parent) {
    $parentFull = (Resolve-FullPath $Parent).TrimEnd('\') + '\'
    (Resolve-FullPath $Child).StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)
}

function Get-SteamRoots {
    $roots = New-Object 'System.Collections.Generic.List[string]'
    foreach ($registryPath in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        try {
            $item = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
            foreach ($property in @('SteamPath','InstallPath')) {
                if ($item.$property) { $roots.Add([string]$item.$property) }
            }
        } catch { }
    }
    foreach ($root in @($roots)) {
        $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf -PathType Leaf) {
            foreach ($line in (Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue)) {
                if ($line -match '^\s*"path"\s*"(.+)"') { $roots.Add(($matches[1] -replace '\\\\','\')) }
            }
        }
    }
    if (${env:ProgramFiles(x86)}) { $roots.Add((Join-Path ${env:ProgramFiles(x86)} 'Steam')) }
    if ($env:ProgramFiles) { $roots.Add((Join-Path $env:ProgramFiles 'Steam')) }
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        $roots.Add((Join-Path $drive.Root 'SteamLibrary'))
    }
    @($roots | Where-Object { $_ } | Select-Object -Unique)
}

function Get-RegisteredGameRoots {
    $roots = New-Object 'System.Collections.Generic.List[string]'
    foreach ($baseKey in @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )) {
        try {
            foreach ($key in (Get-ChildItem -LiteralPath $baseKey -ErrorAction Stop)) {
                try {
                    $entry = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop
                    if ([string]$entry.DisplayName -match '^Sunless Sea(?:\s|$)') {
                        if ($entry.InstallLocation) { $roots.Add([string]$entry.InstallLocation) }
                        elseif ($entry.DisplayIcon) {
                            $iconPath = ([string]$entry.DisplayIcon -replace '^"|"$','') -replace ',\d+$',''
                            if ($iconPath) { $roots.Add((Split-Path -Parent $iconPath)) }
                        }
                    }
                } catch { }
            }
        } catch { }
    }
    @($roots | Where-Object { $_ } | Select-Object -Unique)
}

function Resolve-GameCandidate([string]$Candidate) {
    if (-not $Candidate) { return $null }
    $candidatePath = $Candidate.Trim().Trim('"')
    if (Test-Path -LiteralPath (Join-Path $candidatePath 'Sunless Sea_Data\Managed\Sunless.Game.dll') -PathType Leaf) {
        return (Resolve-FullPath $candidatePath)
    }
    if ((Split-Path -Leaf $candidatePath) -eq 'Sunless Sea_Data' -and
        (Test-Path -LiteralPath (Join-Path $candidatePath 'Managed\Sunless.Game.dll') -PathType Leaf)) {
        return (Resolve-FullPath (Split-Path -Parent $candidatePath))
    }
    return $null
}

function Find-GameRoot([string]$RequestedRoot, [switch]$AllowDialog) {
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    if ($RequestedRoot) { $candidates.Add($RequestedRoot) }
    foreach ($uninstallKey in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304650',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 304650'
    )) {
        try {
            $location = (Get-ItemProperty -LiteralPath $uninstallKey -ErrorAction Stop).InstallLocation
            if ($location) { $candidates.Add([string]$location) }
        } catch { }
    }
    foreach ($registeredRoot in (Get-RegisteredGameRoots)) { $candidates.Add($registeredRoot) }
    foreach ($steamRoot in (Get-SteamRoots)) {
        $candidates.Add((Join-Path $steamRoot 'steamapps\common\SunlessSea'))
        $candidates.Add((Join-Path $steamRoot 'steamapps\common\Sunless Sea'))
    }
    foreach ($programRoot in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($programRoot) {
            $candidates.Add((Join-Path $programRoot 'GOG Galaxy\Games\Sunless Sea'))
            $candidates.Add((Join-Path $programRoot 'GOG Galaxy\Games\SunlessSea'))
        }
    }
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        $candidates.Add((Join-Path $drive.Root 'GOG Games\Sunless Sea'))
        $candidates.Add((Join-Path $drive.Root 'Games\Sunless Sea'))
        $candidates.Add((Join-Path $drive.Root 'Games\SunlessSea'))
    }
    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        $resolved = Resolve-GameCandidate $candidate
        if ($resolved) { return $resolved }
    }
    if ($AllowDialog) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = 'Bitte den Ordner SunlessSea auswählen (nicht den Unterordner Sunless Sea_Data).'
            $dialog.ShowNewFolderButton = $false
            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $selected = $dialog.SelectedPath
                $resolved = Resolve-GameCandidate $selected
                if ($resolved) { return $resolved }
                Write-Warning 'Der ausgewählte Ordner enthält keine unterstützte Sunless.Game.dll.'
            }
        } catch { Write-Warning "Ordnerauswahl konnte nicht geöffnet werden: $($_.Exception.Message)" }
    }
    return $null
}

function Assert-Package($Manifest, [string]$PackageRoot) {
    $addonSource = Join-Path $PackageRoot ('addon\' + $Manifest.Name)
    foreach ($file in @($Manifest.AddonFiles)) {
        $path = Join-Path $addonSource ([string]$file.Path -replace '/','\')
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Paketdatei fehlt: $($file.Path)" }
        if ((Get-Sha256 $path) -ne $file.SHA256) { throw "Paketdatei wurde verändert: $($file.Path)" }
    }
    foreach ($file in @($Manifest.UI.ToolFiles)) {
        $uiPath = Join-Path $PackageRoot ([string]$file.Path -replace '/','\')
        if (-not (Test-Path -LiteralPath $uiPath -PathType Leaf)) { throw "UI-Patchdatei fehlt: $($file.Path)" }
        if ((Get-Sha256 $uiPath) -ne $file.SHA256) { throw "UI-Patchdatei wurde verändert: $($file.Path)" }
    }
    if ($Manifest.Core) {
        foreach ($file in @($Manifest.Core.ToolFiles)) {
            $corePath = Join-Path $PackageRoot ([string]$file.Path -replace '/','\')
            if (-not (Test-Path -LiteralPath $corePath -PathType Leaf)) { throw "Core-Patchdatei fehlt: $($file.Path)" }
            if ((Get-Sha256 $corePath) -ne $file.SHA256) { throw "Core-Patchdatei wurde verändert: $($file.Path)" }
        }
    }
    if ($Manifest.Resources) {
        foreach ($file in @($Manifest.Resources.ToolFiles)) {
            $resourcePath = Join-Path $PackageRoot ([string]$file.Path -replace '/','\')
            if (-not (Test-Path -LiteralPath $resourcePath -PathType Leaf)) { throw "Ressourcen-Patchdatei fehlt: $($file.Path)" }
            if ((Get-Sha256 $resourcePath) -ne $file.SHA256) { throw "Ressourcen-Patchdatei wurde verändert: $($file.Path)" }
        }
    }
}

if (-not $SkipRunningGameCheck -and (Get-Process -Name 'Sunless Sea' -ErrorAction SilentlyContinue)) {
    throw 'Bitte Sunless Sea vor der Installation vollständig beenden.'
}

$packageRoot = Join-Path $PSScriptRoot 'package'
$manifestPath = Join-Path $packageRoot 'package-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'package-manifest.json fehlt. Paket bitte vollständig entpacken.' }
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
Assert-Package $manifest $packageRoot

$null = New-Item -ItemType Directory -Path $StateRoot -Force
$backupRoot = Join-Path $StateRoot 'backups'
$null = New-Item -ItemType Directory -Path $backupRoot -Force
$recordPath = Join-Path $StateRoot 'install-state.json'
$previousRecord = $null
if (Test-Path -LiteralPath $recordPath) {
    $previousRecord = Get-Content -Raw -Encoding UTF8 -LiteralPath $recordPath | ConvertFrom-Json
    Copy-Item -LiteralPath $recordPath -Destination (Join-Path $backupRoot ('state-before-install-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + '.json'))
}

$addonParent = Join-Path $GameDataRoot 'addon'
$destination = Join-Path $addonParent $manifest.Name
if (-not (Test-IsBelow $destination $GameDataRoot)) { throw 'Unerwarteter Addon-Zielpfad. Installation abgebrochen.' }
$null = New-Item -ItemType Directory -Path $addonParent -Force
$stage = Join-Path $addonParent ('.' + $manifest.Name + '-staged-' + [guid]::NewGuid().ToString('N'))
Copy-Item -LiteralPath (Join-Path $packageRoot ('addon\' + $manifest.Name)) -Destination $stage -Recurse
foreach ($file in @($manifest.AddonFiles)) {
    $path = Join-Path $stage ([string]$file.Path -replace '/','\')
    if ((Get-Sha256 $path) -ne $file.SHA256) { throw "Kopierprüfung fehlgeschlagen: $($file.Path)" }
}
if (Test-Path -LiteralPath $destination) {
    $oldAddon = Join-Path $backupRoot ('addon-before-update-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
    Move-Item -LiteralPath $destination -Destination $oldAddon
    Write-Host "Vorige Mod-Fassung gesichert: $oldAddon"
}
Move-Item -LiteralPath $stage -Destination $destination

$record = [ordered]@{
    Name = $manifest.Name
    Version = $manifest.Version
    GameVersion = $manifest.GameVersion
    InstalledAt = [DateTimeOffset]::Now.ToString('o')
    GameDataRoot = (Resolve-FullPath $GameDataRoot)
    AddonDestination = (Resolve-FullPath $destination)
    AddonFiles = @($manifest.AddonFiles)
    UI = $null
    Core = $null
    Resources = $null
}

Write-Host "Geschichtentexte installiert: $destination"

if (-not $NoUI) {
    $resolvedGameRoot = Find-GameRoot $GameRoot -AllowDialog:(-not $NonInteractive)
    if ($resolvedGameRoot) {
        $gameDll = Join-Path $resolvedGameRoot ([string]$manifest.UI.RelativeGameDll -replace '/','\')
        $currentHash = Get-Sha256 $gameDll
        if ($currentHash -eq $manifest.UI.SourceSHA256) {
            $uiBackupFolder = Join-Path $backupRoot ('ui-original-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
            $null = New-Item -ItemType Directory -Path $uiBackupFolder
            $uiBackup = Join-Path $uiBackupFolder 'Sunless.Game.dll'
            Copy-Item -LiteralPath $gameDll -Destination $uiBackup
            if ((Get-Sha256 $uiBackup) -ne $manifest.UI.SourceSHA256) { throw 'Prüfung der UI-Sicherung fehlgeschlagen.' }
            $patchedStage = Join-Path $uiBackupFolder 'Sunless.Game.patched.dll'
            & (Join-Path $packageRoot ([string]$manifest.UI.PatchHelperPath -replace '/','\')) `
                -InputDll $gameDll `
                -OutputDll $patchedStage `
                -ManifestPath (Join-Path $packageRoot ([string]$manifest.UI.PatchManifestPath -replace '/','\')) `
                -CecilPath (Join-Path $packageRoot ([string]$manifest.UI.CecilPath -replace '/','\'))
            if ((Get-Sha256 $patchedStage) -ne $manifest.UI.PatchedSHA256) { throw "UI-Patchergebnis ist unerwartet. Das Original liegt hier: $uiBackup" }
            Copy-Item -LiteralPath $patchedStage -Destination $gameDll
            if ((Get-Sha256 $gameDll) -ne $manifest.UI.PatchedSHA256) { throw "UI-Installation fehlgeschlagen. Das Original liegt hier: $uiBackup" }
            $record.UI = [ordered]@{
                GameRoot = $resolvedGameRoot
                Destination = (Resolve-FullPath $gameDll)
                Backup = (Resolve-FullPath $uiBackup)
                SourceSHA256 = $manifest.UI.SourceSHA256
                PatchedSHA256 = $manifest.UI.PatchedSHA256
                InstalledAt = [DateTimeOffset]::Now.ToString('o')
            }
            Write-Host 'Deutsche Menüs und Mouseover-Texte lokal aus der Original-DLL erzeugt und installiert.'
        }
        elseif ($currentHash -eq $manifest.UI.PatchedSHA256) {
            $oldUi = if ($previousRecord) { $previousRecord.UI } else { $null }
            if ($oldUi -and (Resolve-FullPath ([string]$oldUi.Destination)) -eq (Resolve-FullPath $gameDll) -and
                (Test-Path -LiteralPath ([string]$oldUi.Backup) -PathType Leaf) -and
                (Get-Sha256 ([string]$oldUi.Backup)) -eq $manifest.UI.SourceSHA256) {
                $record.UI = $oldUi
                Write-Host 'Der vorhandene UI-Patch und seine Originalsicherung wurden geprüft und übernommen.'
            }
            else {
                Write-Warning 'Der UI-Patch ist bereits vorhanden, aber keine passende Originalsicherung wurde gefunden. Er wird nicht erneut verändert.'
            }
        }
        elseif ($currentHash -eq 'A368E12380C6B4F4552F854066CE2554C5F9FC37EF5A99658817434E5DC2FA10') {
            Write-Warning 'Eine ältere Unterzee-Deutsch-Oberfläche (0.2) wurde erkannt. Die Geschichten des aktuellen Pakets wurden installiert, doch die alte UI bleibt aus Sicherheitsgründen unverändert. Stelle sie einmal mit dem damaligen Uninstall-UI-Deutsch.ps1 wieder her und starte danach Install.cmd erneut.'
        }
        else {
            Write-Warning ("Die UI-DLL gehört nicht zur unterstützten Spielversion {0}. Der sichere JSON-Sprachmod wurde installiert; die Menüs bleiben Englisch." -f $manifest.GameVersion)
        }

        if ($manifest.Core) {
            $coreDll = Join-Path $resolvedGameRoot ([string]$manifest.Core.RelativeGameDll -replace '/','\')
            if (-not (Test-Path -LiteralPath $coreDll -PathType Leaf)) {
                Write-Warning 'FailBetter.Core.dll wurde nicht gefunden. Generische Logbuch-Ergebnismeldungen bleiben Englisch.'
            }
            else {
                $coreHash = Get-Sha256 $coreDll
                if ($coreHash -eq $manifest.Core.SourceSHA256) {
                    $coreBackupFolder = Join-Path $backupRoot ('core-original-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
                    $null = New-Item -ItemType Directory -Path $coreBackupFolder
                    $coreBackup = Join-Path $coreBackupFolder 'FailBetter.Core.dll'
                    Copy-Item -LiteralPath $coreDll -Destination $coreBackup
                    if ((Get-Sha256 $coreBackup) -ne $manifest.Core.SourceSHA256) { throw 'Prüfung der Core-Sicherung fehlgeschlagen.' }
                    $coreStage = Join-Path $coreBackupFolder 'FailBetter.Core.patched.dll'
                    & (Join-Path $packageRoot ([string]$manifest.Core.PatchHelperPath -replace '/','\')) `
                        -InputDll $coreDll `
                        -OutputDll $coreStage `
                        -ManifestPath (Join-Path $packageRoot ([string]$manifest.Core.PatchManifestPath -replace '/','\')) `
                        -CecilPath (Join-Path $packageRoot ([string]$manifest.Core.CecilPath -replace '/','\'))
                    if ((Get-Sha256 $coreStage) -ne $manifest.Core.PatchedSHA256) { throw "Core-Patchergebnis ist unerwartet. Das Original liegt hier: $coreBackup" }
                    Copy-Item -LiteralPath $coreStage -Destination $coreDll
                    if ((Get-Sha256 $coreDll) -ne $manifest.Core.PatchedSHA256) { throw "Core-Installation fehlgeschlagen. Das Original liegt hier: $coreBackup" }
                    $record.Core = [ordered]@{
                        GameRoot = $resolvedGameRoot; Destination = (Resolve-FullPath $coreDll); Backup = (Resolve-FullPath $coreBackup)
                        SourceSHA256 = $manifest.Core.SourceSHA256; PatchedSHA256 = $manifest.Core.PatchedSHA256
                        InstalledAt = [DateTimeOffset]::Now.ToString('o')
                    }
                    Write-Host 'Deutsche generische Qualitäts- und Logbuchmeldungen lokal aus FailBetter.Core.dll erzeugt und installiert.'
                }
                elseif ($coreHash -eq $manifest.Core.PatchedSHA256) {
                    $oldCore = if ($previousRecord) { $previousRecord.Core } else { $null }
                    if ($oldCore -and (Resolve-FullPath ([string]$oldCore.Destination)) -eq (Resolve-FullPath $coreDll) -and
                        (Test-Path -LiteralPath ([string]$oldCore.Backup) -PathType Leaf) -and
                        (Get-Sha256 ([string]$oldCore.Backup)) -eq $manifest.Core.SourceSHA256) {
                        $record.Core = $oldCore
                        Write-Host 'Der vorhandene Core-Patch und seine Originalsicherung wurden geprüft und übernommen.'
                    }
                    else { Write-Warning 'Der Core-Patch ist bereits vorhanden, aber keine passende Originalsicherung wurde gefunden.' }
                }
                else { Write-Warning ("FailBetter.Core.dll gehört nicht zur unterstützten Spielversion {0} und bleibt unverändert." -f $manifest.GameVersion) }
            }
        }

        if ($manifest.Resources) {
            $resourceFile = Join-Path $resolvedGameRoot ([string]$manifest.Resources.RelativeGamePath -replace '/','\')
            if (-not (Test-Path -LiteralPath $resourceFile -PathType Leaf)) {
                Write-Warning 'Die Oberflächen-Ressourcendatei wurde nicht gefunden. LOGBUCH, Waffenwerte, WERFT, TAUS. und die festen Texte der Kapitänserstellung bleiben in dieser Ansicht Englisch.'
            }
            else {
                $resourceHash = Get-Sha256 $resourceFile
                if ($resourceHash -eq $manifest.Resources.SourceSHA256) {
                    if ((Get-Item -LiteralPath $resourceFile).Length -ne [long]$manifest.Resources.SourceLength) {
                        throw 'Die Oberflächen-Ressourcendatei hat trotz passender Prüfsumme eine unerwartete Länge.'
                    }
                    $resourceBackupFolder = Join-Path $backupRoot ('resources-original-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
                    $null = New-Item -ItemType Directory -Path $resourceBackupFolder
                    $resourceBackup = Join-Path $resourceBackupFolder 'resources.assets'
                    Copy-Item -LiteralPath $resourceFile -Destination $resourceBackup
                    if ((Get-Sha256 $resourceBackup) -ne $manifest.Resources.SourceSHA256) { throw 'Prüfung der Ressourcensicherung fehlgeschlagen.' }
                    $resourceStage = Join-Path $resourceBackupFolder 'resources.patched.assets'
                    & (Join-Path $packageRoot ([string]$manifest.Resources.PatchHelperPath -replace '/','\')) `
                        -InputPath $resourceFile `
                        -OutputPath $resourceStage `
                        -SpecPath (Join-Path $packageRoot ([string]$manifest.Resources.PatchSpecPath -replace '/','\'))
                    if ((Get-Sha256 $resourceStage) -ne $manifest.Resources.PatchedSHA256) { throw "Ressourcen-Patchergebnis ist unerwartet. Das Original liegt hier: $resourceBackup" }
                    Copy-Item -LiteralPath $resourceStage -Destination $resourceFile
                    if ((Get-Sha256 $resourceFile) -ne $manifest.Resources.PatchedSHA256) { throw "Ressourcen-Installation fehlgeschlagen. Das Original liegt hier: $resourceBackup" }
                    $record.Resources = [ordered]@{
                        GameRoot = $resolvedGameRoot
                        Destination = (Resolve-FullPath $resourceFile)
                        Backup = (Resolve-FullPath $resourceBackup)
                        SourceSHA256 = $manifest.Resources.SourceSHA256
                        PatchedSHA256 = $manifest.Resources.PatchedSHA256
                        SourceLength = [long]$manifest.Resources.SourceLength
                        InstalledAt = [DateTimeOffset]::Now.ToString('o')
                    }
                    Write-Host 'LOGBUCH, Waffenwerte, WERFT, TAUS. sowie Namensfeld und Bestätigung der Kapitänserstellung sicher übersetzt.'
                }
                elseif ($resourceHash -eq $manifest.Resources.PatchedSHA256) {
                    $oldResources = if ($previousRecord) { $previousRecord.Resources } else { $null }
                    if ($oldResources -and (Resolve-FullPath ([string]$oldResources.Destination)) -eq (Resolve-FullPath $resourceFile) -and
                        (Test-Path -LiteralPath ([string]$oldResources.Backup) -PathType Leaf) -and
                        (Get-Sha256 ([string]$oldResources.Backup)) -eq $manifest.Resources.SourceSHA256) {
                        $record.Resources = $oldResources
                        Write-Host 'Der vorhandene Ressourcen-Patch und seine Originalsicherung wurden geprüft und übernommen.'
                    }
                    else {
                        Write-Warning 'Der Ressourcen-Patch ist bereits vorhanden, aber keine passende Originalsicherung wurde gefunden. Er wird nicht erneut verändert.'
                    }
                }
                else {
                    Write-Warning ("Die Oberflächen-Ressourcendatei gehört nicht zur unterstützten Spielversion {0}. Sie bleibt unverändert." -f $manifest.GameVersion)
                }
            }
        }
    }
    else {
        Write-Warning 'Sunless Sea wurde nicht gefunden. Der JSON-Sprachmod wurde installiert; der optionale UI-Patch wurde übersprungen.'
    }
}

$record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Host "Installation abgeschlossen (Version $($manifest.Version))."
Write-Host "Installationsnachweis: $recordPath"
