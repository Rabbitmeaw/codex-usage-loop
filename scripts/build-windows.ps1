[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root 'src\CodexUsageLoop.Windows\CodexUsageLoop.Windows.csproj'
$tests = Join-Path $root 'Tests\CodexUsageLoop.Core.Tests\CodexUsageLoop.Core.Tests.csproj'

dotnet restore $project
if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed with exit code $LASTEXITCODE." }
dotnet build $project -c $Configuration --no-restore
if ($LASTEXITCODE -ne 0) { throw "dotnet build failed with exit code $LASTEXITCODE." }
dotnet run --project $tests -c $Configuration
if ($LASTEXITCODE -ne 0) { throw "Core tests failed with exit code $LASTEXITCODE." }

if ($Publish) {
    $output = Join-Path $root 'dist\windows\win-x64'
    dotnet publish $project `
        -c $Configuration `
        -r win-x64 `
        --self-contained false `
        --no-restore `
        -p:PublishSingleFile=true `
        -p:DebugType=None `
        -o $output
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed with exit code $LASTEXITCODE." }
    Write-Output "Published: $output"
}
