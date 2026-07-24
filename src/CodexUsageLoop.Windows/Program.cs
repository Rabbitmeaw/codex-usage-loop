using System.Runtime.InteropServices;

namespace CodexUsageLoop.Windows;

internal static class Program
{
    [STAThread]
    private static int Main()
    {
        // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
        NativeMethods.SetProcessDpiAwarenessContext(new nint(-4));
        var testInstanceId = Environment.GetEnvironmentVariable(
            "CODEX_USAGE_LOOP_TEST_INSTANCE_ID");
        var mutexName = string.IsNullOrWhiteSpace(testInstanceId)
            ? @"Local\CodexUsageLoop.Windows.Singleton"
            : $@"Local\CodexUsageLoop.Windows.Singleton.{testInstanceId}";
        using var mutex = new Mutex(
            initiallyOwned: true,
            mutexName,
            out var isFirstInstance);
        if (!isFirstInstance)
        {
            return 0;
        }

        try
        {
            using var controller = new AppController();
            return controller.Run();
        }
        catch (Exception error)
        {
            Diagnostics.Write($"fatal type={error.GetType().Name} message={error.Message}");
            MessageBoxW(
                0,
                $"CodexUsageLoop 启动失败：\n\n{error.Message}",
                "CodexUsageLoop",
                0x10);
            return 1;
        }
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBoxW(nint hwnd, string text, string caption, uint type);
}
