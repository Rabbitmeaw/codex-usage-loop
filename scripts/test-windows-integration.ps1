[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$appProject = Join-Path $root 'src\CodexUsageLoop.Windows\CodexUsageLoop.Windows.csproj'
$fakeProject = Join-Path $root 'Tests\CodexUsageLoop.FakeCodex\CodexUsageLoop.FakeCodex.csproj'
$appOutput = Join-Path $root 'dist\windows\integration'
$fakeOutput = Join-Path $root 'dist\windows\fake-codex'
$log = Join-Path ([System.IO.Path]::GetTempPath()) "codexusageloop-integration-$([Guid]::NewGuid()).log"

dotnet publish $appProject -c Release -r win-x64 --self-contained false `
    -p:PublishSingleFile=true -p:DebugType=None -o $appOutput
if ($LASTEXITCODE -ne 0) {
    throw "Windows companion publish failed with exit code $LASTEXITCODE."
}
dotnet publish $fakeProject -c Release -r win-x64 --self-contained false `
    -p:PublishSingleFile=true -p:DebugType=None -o $fakeOutput
if ($LASTEXITCODE -ne 0) {
    throw "Fake app-server publish failed with exit code $LASTEXITCODE."
}

$env:CODEX_EXECUTABLE = Join-Path $fakeOutput 'fake-codex.exe'
$env:CODEX_USAGE_LOOP_DIAGNOSTICS = $log
$testInstanceId = [Guid]::NewGuid().ToString('N')
$env:CODEX_USAGE_LOOP_TEST_INSTANCE_ID = $testInstanceId
$windowClass = "CodexUsageLoop.NativeWindow.$testInstanceId"
$process = Start-Process `
    -FilePath (Join-Path $appOutput 'CodexUsageLoop.Windows.exe') `
    -PassThru `
    -WindowStyle Hidden

try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    $passed = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $log) {
            $content = Get-Content -LiteralPath $log -Raw
            if ($content.Contains('usageSnapshot windows=2 primary=72 secondary=81')) {
                $passed = $true
                break
            }
        }
        Start-Sleep -Milliseconds 200
    }
    if (-not $passed) {
        throw "Windows app-server integration did not receive the expected dual-window snapshot."
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CodexUsageLoopTestWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    public static extern IntPtr FindWindow(string className, string title);
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hwnd, uint message, UIntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hwnd, uint message, UIntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll", EntryPoint="GetWindowLongPtrW")]
    public static extern IntPtr GetWindowLongPtr(IntPtr hwnd, int index);
    [DllImport("user32.dll")]
    public static extern uint GetDpiForWindow(IntPtr hwnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("dwmapi.dll")]
    private static extern int DwmGetWindowAttribute(
        IntPtr hwnd, uint attribute, out RECT value, uint valueSize);
    public static bool GetPhysicalWindowRect(IntPtr hwnd, out RECT rect) {
        return DwmGetWindowAttribute(
            hwnd, 9, out rect, (uint)Marshal.SizeOf<RECT>()) == 0;
    }
}
'@
    $controller = [CodexUsageLoopTestWindow]::FindWindow(
        $windowClass,
        'CodexUsageLoop Controller')
    if ($controller -eq [IntPtr]::Zero) {
        throw "Windows controller HWND was not created."
    }
    $ring = [CodexUsageLoopTestWindow]::FindWindow(
        $windowClass,
        'CodexUsageLoop Overlay')
    if ($ring -eq [IntPtr]::Zero) {
        throw "Windows layered ring HWND was not created."
    }
    $card = [CodexUsageLoopTestWindow]::FindWindow(
        $windowClass,
        'CodexUsageLoop Usage')
    if ($card -eq [IntPtr]::Zero) {
        throw "Windows layered card HWND was not created."
    }
    $cardVisibilityToggled = $false
    if (-not [CodexUsageLoopTestWindow]::IsWindowVisible($card)) {
        [CodexUsageLoopTestWindow]::SendMessage(
            $controller, 0x0111, [UIntPtr]::new([uint64]100), [IntPtr]::Zero) | Out-Null
        $cardVisibilityToggled = $true
    }
    if (-not [CodexUsageLoopTestWindow]::IsWindowVisible($card)) {
        throw "Always-visible command did not show the usage card."
    }
    $cardRect = New-Object CodexUsageLoopTestWindow+RECT
    if (-not [CodexUsageLoopTestWindow]::GetPhysicalWindowRect($card, [ref]$cardRect)) {
        throw "Unable to inspect the usage card bounds."
    }
    $dpi = [CodexUsageLoopTestWindow]::GetDpiForWindow($ring)
    $expectedCardWidth = [int][Math]::Round(
        190 * $dpi / 96.0,
        [MidpointRounding]::AwayFromZero)
    $expectedCardHeight = [int][Math]::Round(
        70 * $dpi / 96.0,
        [MidpointRounding]::AwayFromZero)
    $cardWidth = $cardRect.Right - $cardRect.Left
    $cardHeight = $cardRect.Bottom - $cardRect.Top
    if ([Math]::Abs($cardWidth - $expectedCardWidth) -gt 1 -or
        [Math]::Abs($cardHeight - $expectedCardHeight) -gt 1) {
        throw "Usage card was ${cardWidth}x${cardHeight}; expected ${expectedCardWidth}x${expectedCardHeight} at ${dpi} DPI."
    }
    $style = [CodexUsageLoopTestWindow]::GetWindowLongPtr($ring, -20).ToInt64()
    $requiredStyle = 0x00000008L -bor 0x00000080L -bor 0x00080000L -bor 0x08000000L
    if (($style -band $requiredStyle) -ne $requiredStyle -or ($style -band 0x00040000L) -ne 0) {
        throw "Ring HWND is missing topmost/tool/layered/no-activate behavior or exposes APPWINDOW."
    }
    $initialTransparent = ($style -band 0x20L) -ne 0
    $initialHit = [CodexUsageLoopTestWindow]::SendMessage(
        $ring, 0x0084, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64()
    if (($initialTransparent -and $initialHit -ne -1) -or
        (-not $initialTransparent -and $initialHit -ne 2)) {
        throw "Initial hit-testing does not match the configured interaction mode."
    }
    [CodexUsageLoopTestWindow]::SendMessage(
        $controller, 0x0111, [UIntPtr]::new([uint64]101), [IntPtr]::Zero) | Out-Null
    $toggledStyle = [CodexUsageLoopTestWindow]::GetWindowLongPtr($ring, -20).ToInt64()
    $toggledHit = [CodexUsageLoopTestWindow]::SendMessage(
        $ring, 0x0084, [UIntPtr]::Zero, [IntPtr]::Zero).ToInt64()
    if ($initialTransparent) {
        if (($toggledStyle -band 0x20L) -ne 0 -or $toggledHit -ne 2) {
            throw "Manual move mode did not enable HTCAPTION dragging."
        }
    }
    elseif (($toggledStyle -band 0x20L) -eq 0 -or $toggledHit -ne -1) {
        throw "Click-through mode did not restore HTTRANSPARENT."
    }
    [CodexUsageLoopTestWindow]::SendMessage(
        $controller, 0x0111, [UIntPtr]::new([uint64]101), [IntPtr]::Zero) | Out-Null
    if ($cardVisibilityToggled) {
        [CodexUsageLoopTestWindow]::SendMessage(
            $controller, 0x0111, [UIntPtr]::new([uint64]100), [IntPtr]::Zero) | Out-Null
    }

    [CodexUsageLoopTestWindow]::PostMessage(
        $controller,
        0x0010,
        [UIntPtr]::Zero,
        [IntPtr]::Zero) | Out-Null
    if (-not $process.WaitForExit(5000)) {
        throw "Windows companion did not exit after WM_CLOSE."
    }
    $content = Get-Content -LiteralPath $log -Raw
    if (-not $content.Contains('shutdown resourcesReleased=true')) {
        throw "Windows companion did not record complete resource cleanup."
    }
    Write-Output "Windows integration: app-server, ${dpi}-DPI card sizing, layered styles, hit-testing, and graceful shutdown passed"
}
finally {
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
    }
}
