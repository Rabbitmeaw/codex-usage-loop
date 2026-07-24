namespace CodexUsageLoop.Windows;

internal static class Diagnostics
{
    private static readonly object Sync = new();
    private static readonly string? PathValue =
        Environment.GetEnvironmentVariable("CODEX_USAGE_LOOP_DIAGNOSTICS");

    internal static void Write(string message)
    {
        if (string.IsNullOrWhiteSpace(PathValue))
        {
            return;
        }

        lock (Sync)
        {
            try
            {
                File.AppendAllText(
                    PathValue,
                    $"{DateTimeOffset.Now:O} {message}{Environment.NewLine}");
            }
            catch (IOException)
            {
            }
            catch (UnauthorizedAccessException)
            {
            }
        }
    }
}
