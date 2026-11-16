param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

$keyA = [byte[]]@(
    0x7A, 0x31, 0xC4, 0x8E, 0x19, 0xB2, 0x55, 0xE0,
    0x4C, 0x93, 0x27, 0xF1, 0x68, 0xD4, 0x0B, 0xA6,
    0x3E, 0x85, 0xDF, 0x12, 0x79, 0xC0, 0x44, 0x9B,
    0xE7, 0x2A, 0x61, 0xB8, 0x03, 0x5C, 0xA9, 0xF4
)
$keyB = [byte[]]@(
    0x33, 0x5F, 0xB6, 0xE7, 0x6D, 0xC7, 0x26, 0xBF,
    0x1A, 0xFC, 0x5F, 0xA2, 0x07, 0xB8, 0x6A, 0xD4,
    0x57, 0xF6, 0x80, 0x53, 0x0C, 0xA4, 0x2D, 0xF4,
    0xB8, 0x6D, 0x14, 0xD9, 0x71, 0x38, 0x9F, 0xC2
)

$key = New-Object byte[] 32
for ($i = 0; $i -lt 32; $i++) {
    $key[$i] = $keyA[$i] -bxor $keyB[$i]
}

$MusicRoots = @(
    (Join-Path $PSScriptRoot "Audio\Music"),
    (Join-Path $PSScriptRoot "Audio\Music_Lite")
)

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$encryptedCount = 0
$skippedCount = 0
$removedCount = 0

Write-Host "=== Encrypting Music Tracks (.menc) ===" -ForegroundColor Cyan

try {
    foreach ($root in $MusicRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        $audioFiles = Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object {
            $_.Extension.ToLowerInvariant() -in @(".mp3", ".ogg")
        }

        foreach ($file in $audioFiles) {
            $target = "$($file.FullName).menc"

            if (-not $Force -and (Test-Path -LiteralPath $target)) {
                $targetInfo = Get-Item -LiteralPath $target
                if ($targetInfo.LastWriteTimeUtc -ge $file.LastWriteTimeUtc) {
                    $skippedCount++
                    continue
                }
            }

            $ext = $file.Extension.ToLowerInvariant()
            $fmtId = if ($ext -eq ".mp3") { [byte]1 } elseif ($ext -eq ".ogg") { [byte]2 } else { throw "Unsupported extension: $ext" }

            $rawBytes = [System.IO.File]::ReadAllBytes($file.FullName)
            [uint32]$origSize = [uint32]$rawBytes.Length
            $rem = $rawBytes.Length % 16
            $paddedSize = if ($rem -eq 0) { $rawBytes.Length } else { $rawBytes.Length + (16 - $rem) }
            if ($paddedSize -eq 0) {
                $paddedSize = 16
            }

            $padded = New-Object byte[] $paddedSize
            if ($rawBytes.Length -gt 0) {
                [System.Buffer]::BlockCopy($rawBytes, 0, $padded, 0, $rawBytes.Length)
            }

            $iv = New-Object byte[] 16
            $rng.GetBytes($iv)

            $aes = [System.Security.Cryptography.Aes]::Create()
            try {
                $aes.KeySize = 256
                $aes.BlockSize = 128
                $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
                $aes.Padding = [System.Security.Cryptography.PaddingMode]::None
                $aes.Key = $key
                $aes.IV = $iv

                $encryptor = $aes.CreateEncryptor()
                try {
                    $cipherBytes = $encryptor.TransformFinalBlock($padded, 0, $paddedSize)
                } finally {
                    $encryptor.Dispose()
                }
            } finally {
                $aes.Dispose()
            }

            $outBytes = New-Object byte[] (28 + $cipherBytes.Length)
            # Magic "INRM"
            $outBytes[0] = 0x49
            $outBytes[1] = 0x4E
            $outBytes[2] = 0x52
            $outBytes[3] = 0x4D
            # Format ID (1 = mp3, 2 = ogg), bytes 5..7 reserved 0
            $outBytes[4] = $fmtId
            # Original size (Little-Endian UInt32)
            $outBytes[8]  = [byte]($origSize -band 0xFF)
            $outBytes[9]  = [byte](($origSize -shr 8) -band 0xFF)
            $outBytes[10] = [byte](($origSize -shr 16) -band 0xFF)
            $outBytes[11] = [byte](($origSize -shr 24) -band 0xFF)
            # 16-byte IV
            [System.Buffer]::BlockCopy($iv, 0, $outBytes, 12, 16)
            # Ciphertext
            [System.Buffer]::BlockCopy($cipherBytes, 0, $outBytes, 28, $cipherBytes.Length)

            [System.IO.File]::WriteAllBytes($target, $outBytes)
            $encryptedCount++
            Write-Host "Encrypted: $($file.Name) -> $($file.Name).menc" -ForegroundColor Gray
        }

        # Remove orphaned .menc files whose source .mp3/.ogg no longer exists
        $mencFiles = Get-ChildItem -LiteralPath $root -Recurse -File -Filter "*.menc"
        foreach ($mencFile in $mencFiles) {
            $sourcePath = $mencFile.FullName.Substring(0, $mencFile.FullName.Length - 5)
            if (-not (Test-Path -LiteralPath $sourcePath)) {
                Remove-Item -LiteralPath $mencFile.FullName -Force
                $removedCount++
                Write-Host "Removed orphan: $($mencFile.Name)" -ForegroundColor DarkYellow
            }
        }
    }
} finally {
    $rng.Dispose()
}

Write-Host "Music encryption summary: $encryptedCount encrypted, $skippedCount up-to-date, $removedCount orphaned removed." -ForegroundColor Green
