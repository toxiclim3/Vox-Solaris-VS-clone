# This script automatically creates compressed versions (64kbps Stereo) 
# of all music in Audio/Music and puts them into Audio/Music_Lite.

$SourceDir = "Audio/Music"
$TargetDir = "Audio/Music_Lite"

# 1. Check for ffmpeg
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg not found! Please ensure ffmpeg is installed and in your PATH."
    return
}

Write-Host "--- Refreshing Lite Music (64kbps Stereo) ---" -ForegroundColor Cyan

# 2. Mirror the structure and compress
Get-ChildItem -Path $SourceDir -Recurse -File | Where-Object { $_.Extension -in ".mp3", ".ogg", ".wav" } | ForEach-Object {
    # Calculate target path
    $relativePath = $_.FullName.Substring((Get-Item $SourceDir).FullName.Length + 1)
    $targetFile = Join-Path (Get-Item $TargetDir).FullName $relativePath
    $targetFolder = Split-Path $targetFile
    
    # Create directory if missing
    if (-not (Test-Path -Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    }
    
    Write-Host "Compressing: $($_.Name)" -ForegroundColor Gray
    
    # Run ffmpeg (overwrite existing)
    ffmpeg -i $_.FullName -b:a 64k -ac 2 -y $targetFile 2>$null
}

Write-Host "--- Done! Audio/Music_Lite is now up to date. ---" -ForegroundColor Green
