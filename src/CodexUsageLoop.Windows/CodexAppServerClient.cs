using CodexUsageLoop.Core;
using System.Diagnostics;
using System.Text.Json;

namespace CodexUsageLoop.Windows;

internal sealed class CodexAppServerClient : IDisposable
{
    private readonly SemaphoreSlim _writeLock = new(1, 1);
    private Process? _process;
    private StreamWriter? _input;
    private CancellationTokenSource? _cancellation;
    private int _requestId = 10;
    private bool _stopping;

    internal event Action<UsageSnapshot>? SnapshotReceived;
    internal event Action<string>? ErrorReceived;

    internal void Start()
    {
        if (_process is { HasExited: false })
        {
            return;
        }

        var executable = LocateCodexExecutable(out var discoveryError);
        if (executable is null)
        {
            ErrorReceived?.Invoke(discoveryError);
            return;
        }

        _stopping = false;
        _cancellation = new CancellationTokenSource();
        var startInfo = new ProcessStartInfo(executable, "app-server --stdio")
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = System.Text.Encoding.UTF8,
            StandardErrorEncoding = System.Text.Encoding.UTF8
        };
        _process = new Process
        {
            StartInfo = startInfo,
            EnableRaisingEvents = true
        };
        _process.Exited += OnExited;
        try
        {
            _process.Start();
            _input = _process.StandardInput;
            _input.AutoFlush = true;
            _ = ReadOutputAsync(_process, _cancellation.Token);
            _ = DrainErrorAsync(_process, _cancellation.Token);
            _ = SendAsync(new
            {
                id = 1,
                method = "initialize",
                @params = new
                {
                    clientInfo = new
                    {
                        name = "codexusageloop-windows",
                        title = "CodexUsageLoop",
                        version = "0.2.0"
                    },
                    capabilities = new { experimentalApi = true }
                }
            });
        }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            ErrorReceived?.Invoke(error.Message);
            Stop();
        }
    }

    internal void Refresh()
    {
        if (_process is not { HasExited: false })
        {
            Start();
            return;
        }

        _ = SendAsync(new
        {
            id = Interlocked.Increment(ref _requestId),
            method = "account/rateLimits/read",
            @params = (object?)null
        });
    }

    internal void Stop()
    {
        _stopping = true;
        _cancellation?.Cancel();
        _cancellation?.Dispose();
        _cancellation = null;
        _input = null;
        if (_process is not null)
        {
            _process.Exited -= OnExited;
            try
            {
                if (_process.Id != 0 && !_process.HasExited)
                {
                    _process.Kill(entireProcessTree: true);
                    _process.WaitForExit(2_000);
                }
            }
            catch (InvalidOperationException)
            {
            }
            _process.Dispose();
            _process = null;
        }
    }

    public void Dispose()
    {
        Stop();
        _writeLock.Dispose();
    }

    private async Task ReadOutputAsync(Process process, CancellationToken cancellation)
    {
        try
        {
            while (!cancellation.IsCancellationRequested)
            {
                var line = await process.StandardOutput.ReadLineAsync(cancellation);
                if (line is null)
                {
                    break;
                }
                ParseLine(line);
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (IOException error)
        {
            if (!_stopping)
            {
                ErrorReceived?.Invoke(error.Message);
            }
        }
    }

    private static async Task DrainErrorAsync(Process process, CancellationToken cancellation)
    {
        try
        {
            while (await process.StandardError.ReadLineAsync(cancellation) is not null)
            {
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch (IOException)
        {
        }
    }

    private void ParseLine(string line)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            var root = document.RootElement;
            if (root.TryGetProperty("id", out var id)
                && id.TryGetInt32(out var numericId)
                && numericId == 1
                && root.TryGetProperty("result", out _))
            {
                _ = SendAsync(new { method = "initialized" });
                Refresh();
                return;
            }

            if (root.TryGetProperty("result", out var result)
                && result.ValueKind == JsonValueKind.Object
                && result.TryGetProperty("rateLimits", out var resultLimits))
            {
                Publish(resultLimits);
            }
            else if (root.TryGetProperty("method", out var method)
                     && method.GetString() == "account/rateLimits/updated"
                     && root.TryGetProperty("params", out var parameters)
                     && parameters.TryGetProperty("rateLimits", out var updatedLimits))
            {
                Publish(updatedLimits);
            }
        }
        catch (JsonException)
        {
        }
    }

    private void Publish(JsonElement limits)
    {
        var snapshot = RateLimitParser.Parse(limits);
        if (snapshot is not null)
        {
            SnapshotReceived?.Invoke(snapshot);
        }
    }

    private async Task SendAsync<T>(T message)
    {
        var input = _input;
        if (input is null)
        {
            return;
        }

        await _writeLock.WaitAsync();
        try
        {
            await input.WriteLineAsync(JsonSerializer.Serialize(message));
        }
        catch (IOException error)
        {
            if (!_stopping)
            {
                ErrorReceived?.Invoke(error.Message);
            }
        }
        finally
        {
            _writeLock.Release();
        }
    }

    private void OnExited(object? sender, EventArgs args)
    {
        if (!_stopping)
        {
            var code = _process?.ExitCode ?? -1;
            ErrorReceived?.Invoke($"Codex 用量服务已退出（{code}）");
        }
    }

    private static string? LocateCodexExecutable(out string error)
    {
        error = "没有找到独立 Codex CLI；请安装官方 Codex CLI 或设置 CODEX_EXECUTABLE";
        var overridePath = Environment.GetEnvironmentVariable("CODEX_EXECUTABLE");
        if (File.Exists(overridePath))
        {
            return overridePath;
        }

        var candidates = new List<string>
        {
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "npm", "node_modules", "@openai", "codex", "node_modules",
                "@openai", "codex-win32-x64", "vendor", "x86_64-pc-windows-msvc",
                "codex", "codex.exe"),
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Programs", "Codex", "resources", "codex.exe"),
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "Microsoft", "WindowsApps", "codex.exe")
        };
        var path = Environment.GetEnvironmentVariable("PATH") ?? "";
        candidates.AddRange(path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries)
            .Select(directory => Path.Combine(directory.Trim(), "codex.exe")));
        var foundProtectedBundle = candidates.Any(candidate =>
            File.Exists(candidate) && IsProtectedPackagePath(candidate));
        var standalone = candidates.FirstOrDefault(candidate =>
            File.Exists(candidate) && !IsProtectedPackagePath(candidate));
        if (standalone is not null)
        {
            return standalone;
        }

        foreach (var processName in new[] { "codex", "ChatGPT" })
        {
            foreach (var process in Process.GetProcessesByName(processName))
            {
                using (process)
                {
                    try
                    {
                        var processPath = process.MainModule?.FileName;
                        if (processName == "codex" && File.Exists(processPath))
                        {
                            if (IsProtectedPackagePath(processPath))
                            {
                                foundProtectedBundle = true;
                                continue;
                            }
                            return processPath;
                        }
                        var directory = Path.GetDirectoryName(processPath);
                        var bundled = directory is null
                            ? null
                            : Path.Combine(directory, "resources", "codex.exe");
                        if (File.Exists(bundled))
                        {
                            if (IsProtectedPackagePath(bundled))
                            {
                                foundProtectedBundle = true;
                                continue;
                            }
                            return bundled;
                        }
                    }
                    catch (System.ComponentModel.Win32Exception)
                    {
                    }
                    catch (InvalidOperationException)
                    {
                    }
                }
            }
        }

        if (foundProtectedBundle)
        {
            error = "Codex GUI 内置 app-server 受 WindowsApps 保护，外部进程不能直接启动；"
                + "请安装官方独立 Codex CLI 或设置 CODEX_EXECUTABLE";
        }
        return null;
    }

    private static bool IsProtectedPackagePath(string path)
    {
        return path.Contains(
            $"{Path.DirectorySeparatorChar}WindowsApps{Path.DirectorySeparatorChar}",
            StringComparison.OrdinalIgnoreCase);
    }
}
