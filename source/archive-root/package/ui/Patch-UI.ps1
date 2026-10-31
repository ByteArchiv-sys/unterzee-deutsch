[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InputDll,
    [Parameter(Mandatory=$true)][string]$OutputDll,
    [Parameter(Mandatory=$true)][string]$ManifestPath,
    [Parameter(Mandatory=$true)][string]$CecilPath
)

$ErrorActionPreference = 'Stop'
function Get-Sha256([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash }
function Get-AllTypes($Module) {
    $pending = New-Object 'System.Collections.Generic.Stack[Mono.Cecil.TypeDefinition]'
    foreach ($type in $Module.Types) { $pending.Push($type) }
    while ($pending.Count -gt 0) {
        $type = $pending.Pop()
        Write-Output $type
        foreach ($child in $type.NestedTypes) { $pending.Push($child) }
    }
}
function Get-OperandKey($Operand, $Body) {
    if ($null -eq $Operand) { return '<null>' }
    if ($Operand -is [Mono.Cecil.Cil.Instruction]) { return 'branch:' + $Body.Instructions.IndexOf($Operand) }
    if ($Operand -is [Mono.Cecil.Cil.Instruction[]]) {
        return 'switch:' + ((@($Operand | ForEach-Object { $Body.Instructions.IndexOf($_) })) -join ',')
    }
    if ($Operand -is [Mono.Cecil.Cil.VariableDefinition]) { return "local:$($Operand.Index):$($Operand.VariableType.FullName)" }
    if ($Operand -is [Mono.Cecil.ParameterDefinition]) { return "arg:$($Operand.Index):$($Operand.ParameterType.FullName)" }
    return $Operand.ToString()
}
function Get-HexHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($Bytes)) -replace '-','') }
    finally { $sha.Dispose() }
}
function Assert-Equivalent($Original, $Result, [hashtable]$Allowed) {
    if ($Original.Name.FullName -cne $Result.Name.FullName -or $Original.MainModule.Runtime -ne $Result.MainModule.Runtime) { throw 'Assembly-Identität verändert.' }
    if (($Original.MainModule.AssemblyReferences.FullName -join '|') -cne ($Result.MainModule.AssemblyReferences.FullName -join '|')) { throw 'Assembly-Verweise verändert.' }
    if ($Original.MainModule.Resources.Count -ne $Result.MainModule.Resources.Count) { throw 'Ressourcenanzahl verändert.' }
    for ($r=0; $r -lt $Original.MainModule.Resources.Count; $r++) {
        $a = $Original.MainModule.Resources[$r]
        $b = $Result.MainModule.Resources[$r]
        if ($a.Name -cne $b.Name -or $a.ResourceType -ne $b.ResourceType -or $a.Attributes -ne $b.Attributes) { throw 'Ressourcenstruktur verändert.' }
        if ($a -is [Mono.Cecil.EmbeddedResource]) {
            if ((Get-HexHash $a.GetResourceData()) -cne (Get-HexHash $b.GetResourceData())) { throw "Eingebettete Ressource verändert: $($a.Name)" }
        }
    }
    $originalTypes = @(Get-AllTypes $Original.MainModule)
    $resultTypes = @(Get-AllTypes $Result.MainModule)
    if ($originalTypes.Count -ne $resultTypes.Count) { throw 'Typanzahl verändert.' }
    $changedCount = 0
    for ($t=0; $t -lt $originalTypes.Count; $t++) {
        $a = $originalTypes[$t]
        $b = $resultTypes[$t]
        if ($a.FullName -cne $b.FullName -or $a.Attributes -ne $b.Attributes -or $a.Fields.Count -ne $b.Fields.Count -or $a.Methods.Count -ne $b.Methods.Count -or $a.Properties.Count -ne $b.Properties.Count -or $a.Events.Count -ne $b.Events.Count) { throw "Typstruktur verändert: $($a.FullName)" }
        for ($f=0; $f -lt $a.Fields.Count; $f++) {
            if ($a.Fields[$f].FullName -cne $b.Fields[$f].FullName -or $a.Fields[$f].Attributes -ne $b.Fields[$f].Attributes -or $a.Fields[$f].Constant -cne $b.Fields[$f].Constant) { throw "Feld verändert: $($a.Fields[$f].FullName)" }
        }
        for ($m=0; $m -lt $a.Methods.Count; $m++) {
            $am = $a.Methods[$m]
            $bm = $b.Methods[$m]
            if ($am.FullName -cne $bm.FullName -or $am.Attributes -ne $bm.Attributes -or $am.ImplAttributes -ne $bm.ImplAttributes -or $am.HasBody -ne $bm.HasBody) { throw "Methodensignatur verändert: $($am.FullName)" }
            if (-not $am.HasBody) { continue }
            if ($am.Body.Instructions.Count -ne $bm.Body.Instructions.Count -or $am.Body.Variables.Count -ne $bm.Body.Variables.Count -or $am.Body.ExceptionHandlers.Count -ne $bm.Body.ExceptionHandlers.Count -or $am.Body.InitLocals -ne $bm.Body.InitLocals) { throw "Methodenstruktur verändert: $($am.FullName)" }
            for ($v=0; $v -lt $am.Body.Variables.Count; $v++) {
                if ($am.Body.Variables[$v].VariableType.FullName -cne $bm.Body.Variables[$v].VariableType.FullName) { throw 'Lokaler Variablentyp verändert.' }
            }
            for ($i=0; $i -lt $am.Body.Instructions.Count; $i++) {
                $ai = $am.Body.Instructions[$i]
                $bi = $bm.Body.Instructions[$i]
                if ($ai.OpCode.Code -ne $bi.OpCode.Code) { throw "Opcode verändert: $($am.FullName)/$i" }
                $key = "$($am.FullName)|$i"
                if ($Allowed.ContainsKey($key)) {
                    if ($ai.OpCode.Code -ne [Mono.Cecil.Cil.Code]::Ldstr -or $bi.Operand -cne $Allowed[$key]) { throw "Unerwarteter Patch: $key" }
                    $changedCount++
                }
                elseif ((Get-OperandKey $ai.Operand $am.Body) -cne (Get-OperandKey $bi.Operand $bm.Body)) { throw "Unerlaubter Operand verändert: $key" }
            }
            for ($e=0; $e -lt $am.Body.ExceptionHandlers.Count; $e++) {
                $ae = $am.Body.ExceptionHandlers[$e]
                $be = $bm.Body.ExceptionHandlers[$e]
                if ($ae.HandlerType -ne $be.HandlerType -or [string]$ae.CatchType -cne [string]$be.CatchType) { throw 'Ausnahmebehandlung verändert.' }
                foreach ($part in @('TryStart','TryEnd','HandlerStart','HandlerEnd','FilterStart')) {
                    if ((Get-OperandKey $ae.$part $am.Body) -cne (Get-OperandKey $be.$part $bm.Body)) { throw "Ausnahmegrenze verändert: $part" }
                }
            }
        }
    }
    if ($changedCount -ne $Allowed.Count) { throw 'Nicht alle erwarteten Änderungen wurden geprüft.' }
}

$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
if ((Get-Sha256 $InputDll) -ne $manifest.SourceSHA256) {
    throw 'Die Eingabe-DLL ist nicht die exakt unterstützte Originalfassung.'
}
if (-not (Test-Path -LiteralPath $CecilPath -PathType Leaf)) { throw 'Mono.Cecil.dll fehlt.' }
Add-Type -Path $CecilPath

$resolver = New-Object Mono.Cecil.DefaultAssemblyResolver
$resolver.AddSearchDirectory((Split-Path -Parent $InputDll))
$parameters = New-Object Mono.Cecil.ReaderParameters
$parameters.AssemblyResolver = $resolver
$parameters.InMemory = $true
$parameters.ReadSymbols = $false
$source = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($InputDll, $parameters)
$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($InputDll, $parameters)
try {
    if ($assembly.Name.HasPublicKey) { throw 'Unerwartete signierte Assembly. Abbruch.' }
    $methods = @{}
    foreach ($type in @(Get-AllTypes $assembly.MainModule)) {
        foreach ($method in $type.Methods) { $methods[$method.FullName] = $method }
    }
    $changed = 0
    $allowed = @{}
    foreach ($entry in @($manifest.Changes)) {
        $method = $methods[[string]$entry.Method]
        if ($null -eq $method -or -not $method.HasBody) { throw "Patchmethode fehlt: $($entry.Method)" }
        $index = [int]$entry.Instruction
        if ($index -lt 0 -or $index -ge $method.Body.Instructions.Count) { throw "Patchposition fehlt: $($entry.Method) / $index" }
        $instruction = $method.Body.Instructions[$index]
        if ($instruction.OpCode.Code -ne [Mono.Cecil.Cil.Code]::Ldstr -or $instruction.Operand -cne [string]$entry.English) {
            throw "Patchposition stimmt nicht mit dem geprüften Original überein: $($entry.Method) / $index"
        }
        $instruction.Operand = [string]$entry.Deutsch
        $allowed["$($method.FullName)|$index"] = [string]$entry.Deutsch
        $changed++
    }
    if ($changed -ne [int]$manifest.Verification.ChangedStringLiterals) { throw 'Nicht alle erwarteten UI-Texte wurden ersetzt.' }
    Assert-Equivalent $source $assembly $allowed
    $outputParent = Split-Path -Parent $OutputDll
    if ($outputParent) { $null = New-Item -ItemType Directory -Path $outputParent -Force }
    $assembly.Write($OutputDll)
}
finally {
    $assembly.Dispose()
    $source.Dispose()
    $resolver.Dispose()
}
$resultHash = Get-Sha256 $OutputDll
if ($resultHash -ne $manifest.PatchedSHA256) {
    throw "Das lokal erzeugte Patchergebnis weicht vom vollständig geprüften Bauergebnis ab. Erwartet: $($manifest.PatchedSHA256); erhalten: $resultHash"
}
Write-Output "UI-Patch lokal erzeugt: $OutputDll"
