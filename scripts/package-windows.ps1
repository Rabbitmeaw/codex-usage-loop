[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.]+)?$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'build-windows.ps1') -Configuration Release -Publish

$dist = Join-Path $root 'dist'
$publish = Join-Path $dist 'windows\win-x64'
$archive = Join-Path $dist "CodexUsageLoop-Windows-x64-$Version.zip"
$checksum = "$archive.sha256"

Compress-Archive -Path (Join-Path $publish '*') -DestinationPath $archive -Force
$hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $archive)" | Set-Content -LiteralPath $checksum -Encoding ascii

Write-Output "Release artifacts:"
Write-Output "  $archive"
Write-Output "  $checksum"
