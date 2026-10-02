[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+)?$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# Embed the nearest-release describe for source builds; release CI checkouts
# may not fetch tags, and the v-prefix guard keeps hash-only output from being
# embedded so release artifacts fall back to the assembly version.
$sourceVersionPath = Join-Path $root 'src\CodexUsageLoop.Windows\SourceVersion.txt'
Push-Location $root
try {
    $describe = git describe --tags --always --dirty 2>$null
}
finally {
    Pop-Location
}
$embedded = $false
if ($describe -match '^v[0-9]') {
    [System.IO.File]::WriteAllText(
        $sourceVersionPath,
        "$describe`n",
        (New-Object System.Text.UTF8Encoding($false)))
    $embedded = $true
}

try {
& (Join-Path $PSScriptRoot 'build-windows.ps1') -Configuration Release -Publish

$dist = Join-Path $root 'dist'
$publish = Join-Path $dist 'windows\win-x64'
$archive = Join-Path $dist "CodexUsageLoop-Windows-x64-$Version.zip"
$checksum = "$archive.sha256"

Compress-Archive -Path (Join-Path $publish '*') -DestinationPath $archive -Force
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText(
    $checksum,
    "$hash  $(Split-Path -Leaf $archive)`n",
    [System.Text.Encoding]::ASCII)

Write-Output "Release artifacts:"
Write-Output "  $archive"
Write-Output "  $checksum"
}
finally {
    if ($embedded -and (Test-Path -LiteralPath $sourceVersionPath)) {
        Remove-Item -LiteralPath $sourceVersionPath -Force
    }
}
