param(
    [string]$Version
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$ProjectFile = Join-Path $PSScriptRoot "project.godot"
$PresetsFile = Join-Path $PSScriptRoot "export_presets.cfg"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath $ProjectFile)) {
    Write-Host "ERROR: project.godot not found at $ProjectFile" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $PresetsFile)) {
    Write-Host "ERROR: export_presets.cfg not found at $PresetsFile" -ForegroundColor Red
    exit 1
}

$projectContent = [System.IO.File]::ReadAllText($ProjectFile, $Utf8NoBom)
$versionMatch = [regex]::Match($projectContent, '(?m)^config/version="([^"]*)"')
if (-not $versionMatch.Success) {
    Write-Host "ERROR: Could not find config/version in project.godot" -ForegroundColor Red
    exit 1
}
$currentVersion = $versionMatch.Groups[1].Value

if ([string]::IsNullOrWhiteSpace($Version)) {
    $promptInput = Read-Host "Enter version to export (current: $currentVersion, press Enter to use $currentVersion)"
    if ([string]::IsNullOrWhiteSpace($promptInput)) {
        $Version = $currentVersion
    } else {
        $Version = $promptInput
    }
}

$Version = $Version.Trim() -replace '^[vV]+', ''
if ($Version -notmatch '^\d+\.\d+(\.\d+)?$') {
    Write-Host "ERROR: Invalid version '$Version'. Expected format like 1.1.0 or 1.2." -ForegroundColor Red
    exit 1
}

$parts = $Version.Split('.')
$MajorMinor = "$($parts[0]).$($parts[1])"
$Patch = if ($parts.Count -ge 3) { [int]$parts[2] } else { 0 }
$VersionCode = ([int]$parts[0] * 100) + ([int]$parts[1] * 10) + $Patch

Write-Host "=== Preparing release v$Version (Folder: $MajorMinor, Android versionCode: $VersionCode) ===" -ForegroundColor Cyan

# Update project.godot
$updatedProject = [regex]::Replace(
    $projectContent,
    '(?m)^config/version="[^"]*"',
    "config/version=`"$Version`""
)
[System.IO.File]::WriteAllText($ProjectFile, $updatedProject, $Utf8NoBom)
Write-Host "Updated project.godot -> config/version=`"$Version`"" -ForegroundColor Gray

# Update export_presets.cfg
$presetsContent = [System.IO.File]::ReadAllText($PresetsFile, $Utf8NoBom)
$replacements = @(
    @{
        Name = "macOS export_path"
        Pattern = '(?m)^export_path="\.\./[Bb]uilds/[^"\r\n]*_mac\.zip"'
        Value = "export_path=`"../Builds/$MajorMinor/Inritus_${Version}_mac.zip`""
    },
    @{
        Name = "Windows Desktop Lite export_path"
        Pattern = '(?m)^export_path="\.\./[Bb]uilds/[^"\r\n]*_Lite\.exe"'
        Value = "export_path=`"../Builds/$MajorMinor/Inritus_${Version}_Lite.exe`""
    },
    @{
        Name = "Android export_path"
        Pattern = '(?m)^export_path="\.\./[Bb]uilds/[^"\r\n]*\.apk"'
        Value = "export_path=`"../Builds/$MajorMinor/Inritus_${Version}.apk`""
    },
    @{
        Name = "Windows Desktop export_path"
        Pattern = '(?m)^export_path="\.\./[Bb]uilds/(?![^"\r\n]*_Lite)[^"\r\n]*\.exe"'
        Value = "export_path=`"../Builds/$MajorMinor/Inritus_${Version}.exe`""
    },
    @{
        Name = "Android version/code"
        Pattern = '(?m)^version/code=\d+'
        Value = "version/code=$VersionCode"
    },
    @{
        Name = "Android version/name"
        Pattern = '(?m)^version/name="[^"]*"'
        Value = "version/name=`"$Version`""
    }
)

foreach ($rule in $replacements) {
    if (-not [regex]::IsMatch($presetsContent, $rule.Pattern)) {
        Write-Host "ERROR: Could not find expected field in export_presets.cfg for: $($rule.Name)" -ForegroundColor Red
        exit 1
    }
    $presetsContent = [regex]::Replace($presetsContent, $rule.Pattern, $rule.Value)
}

[System.IO.File]::WriteAllText($PresetsFile, $presetsContent, $Utf8NoBom)
Write-Host "Updated export_presets.cfg paths and Android version info." -ForegroundColor Gray

# Resolve Godot binary
$godotCmd = Get-Command godot -ErrorAction SilentlyContinue
if ($godotCmd) {
    $GodotExe = $godotCmd.Source
} else {
    $GodotExe = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\godot.exe"))
}

if (-not (Test-Path -LiteralPath $GodotExe)) {
    Write-Host "ERROR: Godot executable not found in PATH or at $GodotExe" -ForegroundColor Red
    exit 1
}
Write-Host "Using Godot: $GodotExe" -ForegroundColor Gray

# Encrypt music tracks before exporting
$EncryptScript = Join-Path $PSScriptRoot "encrypt_music.ps1"
if (-not (Test-Path -LiteralPath $EncryptScript)) {
    Write-Host "ERROR: encrypt_music.ps1 not found at $EncryptScript" -ForegroundColor Red
    exit 1
}
& $EncryptScript
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Music encryption failed." -ForegroundColor Red
    exit 1
}

# Create output directory
$BuildDir = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) "Builds\$MajorMinor"))
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
Write-Host "Output directory: $BuildDir" -ForegroundColor Gray

$targets = @(
    @{ Preset = "Windows Desktop";      Output = (Join-Path $BuildDir "Inritus_${Version}.exe") },
    @{ Preset = "Windows Desktop Lite"; Output = (Join-Path $BuildDir "Inritus_${Version}_Lite.exe") },
    @{ Preset = "Android";              Output = (Join-Path $BuildDir "Inritus_${Version}.apk") },
    @{ Preset = "macOS";                Output = (Join-Path $BuildDir "Inritus_${Version}_mac.zip") }
)

$results = @()
$hasFailure = $false

foreach ($target in $targets) {
    Write-Host ""
    Write-Host ">>> Exporting $($target.Preset) -> $($target.Output)" -ForegroundColor Yellow

    $argList = @(
        "--headless"
        "--path"
        "`"$PSScriptRoot`""
        "--export-release"
        "`"$($target.Preset)`""
        "`"$($target.Output)`""
    )

    $proc = Start-Process -FilePath $GodotExe -ArgumentList $argList -WorkingDirectory $PSScriptRoot -Wait -NoNewWindow -PassThru
    $exists = Test-Path -LiteralPath $target.Output
    $sizeMB = if ($exists) { [math]::Round((Get-Item -LiteralPath $target.Output).Length / 1MB, 2) } else { 0 }
    $ok = ($proc.ExitCode -eq 0) -and $exists -and ($sizeMB -gt 0)

    if (-not $ok) {
        $hasFailure = $true
    }

    $results += [PSCustomObject]@{
        Platform = $target.Preset
        Status   = if ($ok) { "OK" } else { "FAILED (exit $($proc.ExitCode))" }
        SizeMB   = if ($exists) { "$sizeMB MB" } else { "-" }
        File     = $target.Output
    }
}

Write-Host ""
Write-Host "=== Export Summary (v$Version) ===" -ForegroundColor Cyan
$results | Format-Table -Property Platform, Status, SizeMB, File -AutoSize

if ($hasFailure) {
    Write-Host "One or more exports failed. Check the Godot output above." -ForegroundColor Red
    exit 1
}

Write-Host "All exports completed successfully!" -ForegroundColor Green
