using CodexUsageLoop.Core;
using System.Diagnostics;
using System.Text.Json;

namespace CodexUsageLoop.Windows;

internal sealed record PetLocation(
    RectD Frame,
    RectD WorkArea,
    string? Placement,
    double Scale);

internal sealed class PetLocator
{
    private readonly string _statePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".codex",
        ".codex-global-state.json");

    internal bool IsExplicitlyHidden { get; private set; }

    internal PetLocation? Locate()
    {
        var persisted = LocateFromPersistedState();
        if (persisted is not null || IsExplicitlyHidden)
        {
            return persisted;
        }

        return LocateFromWindow();
    }

    private PetLocation? LocateFromPersistedState()
    {
        try
        {
            using var stream = new FileStream(
                _statePath,
                FileMode.Open,
                FileAccess.Read,
                FileShare.ReadWrite | FileShare.Delete);
            using var document = JsonDocument.Parse(stream);
            var root = document.RootElement;
            IsExplicitlyHidden = root.TryGetProperty("electron-avatar-overlay-open", out var open)
                && open.ValueKind is JsonValueKind.False;
            if (IsExplicitlyHidden
                || !root.TryGetProperty("electron-avatar-overlay-bounds", out var state)
                || state.ValueKind != JsonValueKind.Object)
            {
                return null;
            }

            if (!TryNumber(state, "x", out var x)
                || !TryNumber(state, "y", out var y)
                || !state.TryGetProperty("displayBounds", out var display)
                || !TryRect(display, out var logicalDisplay))
            {
                return null;
            }

            var placement = state.TryGetProperty("placement", out var placementValue)
                ? placementValue.GetString()
                : null;
            var width = TryNumber(state, "width", out var storedWidth) ? storedWidth : 119;
            var height = TryNumber(state, "height", out var storedHeight) ? storedHeight : 129;
            if (state.TryGetProperty("mascot", out var mascot)
                && mascot.ValueKind == JsonValueKind.Object
                && TryNumber(mascot, "left", out var left)
                && TryNumber(mascot, "top", out var top)
                && TryNumber(mascot, "width", out var mascotWidth)
                && TryNumber(mascot, "height", out var mascotHeight))
            {
                x += left;
                y += top;
                width = mascotWidth;
                height = mascotHeight;
            }

            var monitor = MatchMonitor(logicalDisplay);
            if (monitor is null)
            {
                return null;
            }

            var scaleX = monitor.Value.Bounds.Width / logicalDisplay.Width;
            var scaleY = monitor.Value.Bounds.Height / logicalDisplay.Height;
            var frame = new RectD(
                monitor.Value.Bounds.X + (x - logicalDisplay.X) * scaleX,
                monitor.Value.Bounds.Y + (y - logicalDisplay.Y) * scaleY,
                width * scaleX,
                height * scaleY);
            return frame.IsValid
                ? new PetLocation(
                    frame,
                    monitor.Value.WorkArea,
                    placement,
                    (scaleX + scaleY) / 2)
                : null;
        }
        catch (IOException)
        {
            return null;
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static PetLocation? LocateFromWindow()
    {
        var candidates = new List<(RectD Frame, string Title, double Scale)>();
        NativeMethods.EnumWindows((hwnd, _) =>
        {
            if (!NativeMethods.IsWindowVisible(hwnd)
                || !NativeMethods.GetWindowRect(hwnd, out var rect)
                || rect.Width < 40 || rect.Height < 40
                || rect.Width > 900 || rect.Height > 900)
            {
                return true;
            }

            NativeMethods.GetWindowThreadProcessId(hwnd, out var processId);
            try
            {
                using var process = Process.GetProcessById((int)processId);
                if (!process.ProcessName.Contains("Codex", StringComparison.OrdinalIgnoreCase)
                    && !process.ProcessName.Contains("ChatGPT", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            catch (ArgumentException)
            {
                return true;
            }
            catch (InvalidOperationException)
            {
                return true;
            }

            var titleBuffer = new char[256];
            var titleLength = NativeMethods.GetWindowTextW(hwnd, titleBuffer, titleBuffer.Length);
            var title = titleLength > 0 ? new string(titleBuffer, 0, titleLength) : "";
            var scale = Math.Max(96, NativeMethods.GetDpiForWindow(hwnd)) / 96.0;
            candidates.Add((
                new RectD(rect.left, rect.top, rect.Width, rect.Height),
                title,
                scale));
            return true;
        }, 0);

        var candidate = candidates
            .OrderByDescending(item =>
                (item.Title.Contains("pet", StringComparison.OrdinalIgnoreCase) ? 100_000 : 0)
                - item.Frame.Width * item.Frame.Height)
            .FirstOrDefault();
        if (!candidate.Frame.IsValid)
        {
            return null;
        }

        var monitor = MonitorAt(new PointD(candidate.Frame.CenterX, candidate.Frame.CenterY));
        if (monitor is null)
        {
            return null;
        }

        var pet = UsageGeometry.EstimateMascot(candidate.Frame, monitor.Value.Bounds, null);
        return new PetLocation(pet, monitor.Value.WorkArea, null, candidate.Scale);
    }

    private static MonitorGeometry? MatchMonitor(RectD logicalDisplay)
    {
        return EnumerateMonitors()
            .OrderBy(monitor =>
            {
                var scaleX = monitor.Bounds.Width / logicalDisplay.Width;
                var scaleY = monitor.Bounds.Height / logicalDisplay.Height;
                var logicalLeft = monitor.Bounds.Left / Math.Max(scaleX, 0.01);
                var logicalTop = monitor.Bounds.Top / Math.Max(scaleY, 0.01);
                return Math.Abs(scaleX - scaleY) * 10_000
                    + Math.Abs(logicalLeft - logicalDisplay.Left)
                    + Math.Abs(logicalTop - logicalDisplay.Top)
                    + Math.Abs(monitor.Bounds.Width / monitor.Bounds.Height
                               - logicalDisplay.Width / logicalDisplay.Height) * 1_000;
            })
            .Cast<MonitorGeometry?>()
            .FirstOrDefault();
    }

    private static MonitorGeometry? MonitorAt(PointD point)
    {
        var handle = NativeMethods.MonitorFromPoint(
            new NativeMethods.POINT((int)Math.Round(point.X), (int)Math.Round(point.Y)),
            NativeMethods.MONITOR_DEFAULTTONEAREST);
        return handle == 0 ? null : GetMonitor(handle);
    }

    private static IReadOnlyList<MonitorGeometry> EnumerateMonitors()
    {
        var result = new List<MonitorGeometry>();
        NativeMethods.EnumDisplayMonitors(0, 0, (
            nint monitor,
            nint monitorDc,
            ref NativeMethods.RECT monitorRect,
            nint data) =>
        {
            var value = GetMonitor(monitor);
            if (value is not null)
            {
                result.Add(value.Value);
            }
            return true;
        }, 0);
        return result;
    }

    private static MonitorGeometry? GetMonitor(nint monitor)
    {
        var info = new NativeMethods.MONITORINFOEX
        {
            cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf<NativeMethods.MONITORINFOEX>(),
            szDevice = ""
        };
        if (!NativeMethods.GetMonitorInfoW(monitor, ref info))
        {
            return null;
        }
        return new MonitorGeometry(
            new RectD(info.rcMonitor.left, info.rcMonitor.top, info.rcMonitor.Width, info.rcMonitor.Height),
            new RectD(info.rcWork.left, info.rcWork.top, info.rcWork.Width, info.rcWork.Height));
    }

    private static bool TryRect(JsonElement value, out RectD rect)
    {
        if (TryNumber(value, "x", out var x)
            && TryNumber(value, "y", out var y)
            && TryNumber(value, "width", out var width)
            && TryNumber(value, "height", out var height))
        {
            rect = new RectD(x, y, width, height);
            return rect.IsValid;
        }
        rect = default;
        return false;
    }

    private static bool TryNumber(JsonElement value, string name, out double number)
    {
        if (value.TryGetProperty(name, out var property)
            && property.ValueKind == JsonValueKind.Number
            && property.TryGetDouble(out number))
        {
            return true;
        }
        number = 0;
        return false;
    }

    private readonly record struct MonitorGeometry(RectD Bounds, RectD WorkArea);
}
