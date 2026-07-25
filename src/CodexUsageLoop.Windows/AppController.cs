using CodexUsageLoop.Core;
using System.Collections.Concurrent;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace CodexUsageLoop.Windows;

internal sealed class AppController : IDisposable
{
    private static readonly string WindowClass = BuildWindowClass();
    private const nuint OverlayTimer = 1;
    private const nuint RefreshTimer = 2;
    private const nuint AnimationTimer = 3;
    private const uint TrayId = 1;

    private const int CommandAlwaysVisible = 100;
    private const int CommandManualMove = 101;
    private const int CommandPlacementAround = 110;
    private const int CommandPlacementLeft = 111;
    private const int CommandPlacementRight = 112;
    private const int CommandScale75 = 120;
    private const int CommandScale100 = 121;
    private const int CommandScale125 = 122;
    private const int CommandScale150 = 123;
    private const int CommandOuterColor = 130;
    private const int CommandInnerColor = 131;
    private const int CommandDefaultColors = 132;
    private const int CommandLaunchWithPet = 140;
    private const int CommandDemo = 141;
    private const int CommandRefresh = 150;
    private const int CommandRecalibrate = 151;
    private const int CommandOpenReleases = 152;
    private const int CommandQuit = 199;

    private static readonly NativeMethods.WindowProc WindowProcedure = WndProc;
    private static AppController? _current;

    private readonly GdiPlusRuntime _gdiPlus = new();
    private readonly LayeredRenderer _renderer = new();
    private readonly SettingsStore _settingsStore = new();
    private readonly PetLocator _petLocator = new();
    private readonly CodexAppServerClient _client = new();
    private readonly ConcurrentQueue<UsageSnapshot> _snapshots = new();
    private readonly ConcurrentQueue<string> _errors = new();
    private readonly UsageState _state;
    private readonly nint _instance;
    private nint _messageWindow;
    private nint _ringWindow;
    private nint _cardWindow;
    private nint _trayIcon;
    private NativeMethods.NOTIFYICONDATA _notifyData;
    private PetLocation? _lastPet;
    private PointD _lastRingCenter = new(129, 729);
    private double _ringSize = 210;
    private double _displayOuterPercent;
    private double? _displayInnerPercent;
    private bool _animationRunning;
    private bool _clientRunning;
    private bool _disposed;
    private bool _suppressMovePersistence;
    private bool _forceRender = true;
    private string? _lastRingRenderKey;
    private DateTime _lastPresenceCheck = DateTime.MinValue;
    private bool _codexRunning;

    internal AppController()
    {
        _current = this;
        _instance = NativeMethods.GetModuleHandleW(null);
        _state = _settingsStore.Load();
        RegisterWindowClass();
        CreateWindows();
        AddTrayIcon();

        _client.SnapshotReceived += snapshot =>
        {
            _snapshots.Enqueue(snapshot);
            NativeMethods.PostMessageW(_messageWindow, NativeMethods.WM_APP_SNAPSHOT, 0, 0);
        };
        _client.ErrorReceived += error =>
        {
            _errors.Enqueue(error);
            NativeMethods.PostMessageW(_messageWindow, NativeMethods.WM_APP_ERROR, 0, 0);
        };

        ApplyInteractionMode();
        StartClient();
        NativeMethods.SetTimer(_messageWindow, OverlayTimer, 1_000, 0);
        NativeMethods.SetTimer(_messageWindow, RefreshTimer, 30_000, 0);
        UpdateOverlay(force: true);
        Diagnostics.Write(
            $"started message=0x{_messageWindow:X} ring=0x{_ringWindow:X} card=0x{_cardWindow:X} "
            + $"dpi=PerMonitorV2 ringExStyle=0x{NativeMethods.GetWindowLongPtrW(_ringWindow, NativeMethods.GWL_EXSTYLE).ToInt64():X}");
    }

    private static string BuildWindowClass()
    {
        var testInstanceId = Environment.GetEnvironmentVariable(
            "CODEX_USAGE_LOOP_TEST_INSTANCE_ID");
        return string.IsNullOrWhiteSpace(testInstanceId)
            ? "CodexUsageLoop.NativeWindow"
            : $"CodexUsageLoop.NativeWindow.{testInstanceId}";
    }

    internal int Run()
    {
        while (NativeMethods.GetMessageW(out var message, 0, 0, 0) > 0)
        {
            NativeMethods.TranslateMessage(ref message);
            NativeMethods.DispatchMessageW(ref message);
        }
        return 0;
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }
        _disposed = true;

        NativeMethods.KillTimer(_messageWindow, OverlayTimer);
        NativeMethods.KillTimer(_messageWindow, RefreshTimer);
        NativeMethods.KillTimer(_messageWindow, AnimationTimer);
        _client.Dispose();
        RemoveTrayIcon();
        _renderer.Dispose();
        if (_cardWindow != 0)
        {
            NativeMethods.DestroyWindow(_cardWindow);
            _cardWindow = 0;
        }
        if (_ringWindow != 0)
        {
            NativeMethods.DestroyWindow(_ringWindow);
            _ringWindow = 0;
        }
        if (_messageWindow != 0)
        {
            NativeMethods.DestroyWindow(_messageWindow);
            _messageWindow = 0;
        }
        if (_trayIcon != 0)
        {
            NativeMethods.DestroyIcon(_trayIcon);
            _trayIcon = 0;
        }
        _gdiPlus.Dispose();
        _current = null;
        Diagnostics.Write("shutdown resourcesReleased=true");
    }

    private void RegisterWindowClass()
    {
        var windowClass = new NativeMethods.WNDCLASSEX
        {
            cbSize = (uint)Marshal.SizeOf<NativeMethods.WNDCLASSEX>(),
            lpfnWndProc = WindowProcedure,
            hInstance = _instance,
            lpszClassName = WindowClass
        };
        if (NativeMethods.RegisterClassExW(ref windowClass) == 0)
        {
            throw new InvalidOperationException(
                $"RegisterClassExW failed ({Marshal.GetLastWin32Error()}).");
        }
    }

    private void CreateWindows()
    {
        _messageWindow = CreateWindow(0, "CodexUsageLoop Controller", 0, 0, 1, 1);
        _ringWindow = CreateWindow(
            NativeMethods.WS_EX_TOPMOST
            | NativeMethods.WS_EX_TOOLWINDOW
            | NativeMethods.WS_EX_LAYERED
            | NativeMethods.WS_EX_NOACTIVATE
            | NativeMethods.WS_EX_TRANSPARENT,
            "CodexUsageLoop Overlay",
            24,
            24,
            226,
            226);
        _cardWindow = CreateWindow(
            NativeMethods.WS_EX_TOPMOST
            | NativeMethods.WS_EX_TOOLWINDOW
            | NativeMethods.WS_EX_LAYERED
            | NativeMethods.WS_EX_NOACTIVATE
            | NativeMethods.WS_EX_TRANSPARENT,
            "CodexUsageLoop Usage",
            250,
            24,
            190,
            54);
    }

    private nint CreateWindow(uint extendedStyle, string title, int x, int y, int width, int height)
    {
        var hwnd = NativeMethods.CreateWindowExW(
            extendedStyle,
            WindowClass,
            title,
            NativeMethods.WS_POPUP,
            x,
            y,
            width,
            height,
            0,
            0,
            _instance,
            0);
        if (hwnd == 0)
        {
            throw new InvalidOperationException(
                $"CreateWindowExW failed ({Marshal.GetLastWin32Error()}).");
        }
        return hwnd;
    }

    private void AddTrayIcon()
    {
        _trayIcon = _renderer.CreateTrayIcon();
        _notifyData = new NativeMethods.NOTIFYICONDATA
        {
            cbSize = (uint)Marshal.SizeOf<NativeMethods.NOTIFYICONDATA>(),
            hWnd = _messageWindow,
            uID = TrayId,
            uFlags = NativeMethods.NIF_MESSAGE | NativeMethods.NIF_ICON | NativeMethods.NIF_TIP,
            uCallbackMessage = NativeMethods.WM_TRAYICON,
            hIcon = _trayIcon,
            szTip = "CodexUsageLoop",
            szInfo = "",
            szInfoTitle = ""
        };
        if (!NativeMethods.Shell_NotifyIconW(NativeMethods.NIM_ADD, ref _notifyData))
        {
            throw new InvalidOperationException("Shell_NotifyIconW failed.");
        }
        _notifyData.uVersion = NativeMethods.NOTIFYICON_VERSION_4;
        NativeMethods.Shell_NotifyIconW(NativeMethods.NIM_SETVERSION, ref _notifyData);
    }

    private void RemoveTrayIcon()
    {
        if (_notifyData.hWnd != 0)
        {
            NativeMethods.Shell_NotifyIconW(NativeMethods.NIM_DELETE, ref _notifyData);
            _notifyData.hWnd = 0;
        }
    }

    private static nint WndProc(nint hwnd, uint message, nuint wParam, nint lParam)
    {
        var controller = _current;
        if (controller is null)
        {
            return NativeMethods.DefWindowProcW(hwnd, message, wParam, lParam);
        }

        if (message == NativeMethods.WM_NCHITTEST)
        {
            if (hwnd == controller._ringWindow)
            {
                return controller._state.ManualMove
                    ? NativeMethods.HTCAPTION
                    : NativeMethods.HTTRANSPARENT;
            }
            if (hwnd == controller._cardWindow)
            {
                return NativeMethods.HTTRANSPARENT;
            }
        }

        if (hwnd == controller._ringWindow
            && message == NativeMethods.WM_MOVE
            && controller._state.ManualMove
            && !controller._suppressMovePersistence
            && NativeMethods.GetWindowRect(hwnd, out var movedRect))
        {
            controller._settingsStore.SaveManualPosition(movedRect.left, movedRect.top);
            controller._lastRingCenter = new PointD(
                movedRect.left + movedRect.Width / 2.0,
                movedRect.top + movedRect.Height / 2.0);
            controller._forceRender = true;
            return 0;
        }

        if (hwnd == controller._messageWindow)
        {
            switch (message)
            {
                case NativeMethods.WM_TIMER:
                    controller.OnTimer(wParam);
                    return 0;
                case NativeMethods.WM_COMMAND:
                    controller.OnCommand(unchecked((int)(wParam & 0xFFFF)));
                    return 0;
                case NativeMethods.WM_TRAYICON:
                    var notification = unchecked((uint)lParam.ToInt64()) & 0xFFFF;
                    if (notification is NativeMethods.WM_RBUTTONUP
                        or NativeMethods.WM_CONTEXTMENU
                        or NativeMethods.WM_LBUTTONUP)
                    {
                        controller.ShowTrayMenu();
                    }
                    return 0;
                case NativeMethods.WM_APP_SNAPSHOT:
                    controller.ApplySnapshots();
                    return 0;
                case NativeMethods.WM_APP_ERROR:
                    controller.ApplyErrors();
                    return 0;
                case NativeMethods.WM_CLOSE:
                case NativeMethods.WM_ENDSESSION:
                    NativeMethods.DestroyWindow(hwnd);
                    return 0;
                case NativeMethods.WM_DESTROY:
                    NativeMethods.PostQuitMessage(0);
                    return 0;
            }
        }

        return NativeMethods.DefWindowProcW(hwnd, message, wParam, lParam);
    }

    private void OnTimer(nuint timer)
    {
        if (timer == OverlayTimer)
        {
            UpdateCodexPresence();
            UpdateClientLifecycle();
            UpdateOverlay();
        }
        else if (timer == RefreshTimer)
        {
            if (_clientRunning)
            {
                _client.Refresh();
            }
        }
        else if (timer == AnimationTimer)
        {
            AdvanceAnimation();
        }
    }

    private void UpdateCodexPresence()
    {
        if ((DateTime.UtcNow - _lastPresenceCheck).TotalSeconds < 1)
        {
            return;
        }
        _lastPresenceCheck = DateTime.UtcNow;
        _codexRunning = Process.GetProcesses()
            .Any(process =>
            {
                using (process)
                {
                    return process.ProcessName.Equals("Codex", StringComparison.OrdinalIgnoreCase)
                        || process.ProcessName.Equals("ChatGPT", StringComparison.OrdinalIgnoreCase);
                }
            });
    }

    private void UpdateClientLifecycle()
    {
        var shouldRun = !_state.LaunchWithCodexPet || _codexRunning;
        if (shouldRun && !_clientRunning)
        {
            StartClient();
        }
        else if (!shouldRun && _clientRunning)
        {
            _client.Stop();
            _clientRunning = false;
            HideOverlays();
        }
    }

    private void StartClient()
    {
        if (_clientRunning)
        {
            return;
        }
        _clientRunning = true;
        _client.Start();
    }

    private void ApplySnapshots()
    {
        while (_snapshots.TryDequeue(out var snapshot))
        {
            var hadSnapshot = _state.Snapshot is not null;
            _state.Snapshot = snapshot;
            _state.ErrorMessage = null;
            Diagnostics.Write(
                $"usageSnapshot windows={snapshot.Windows.Count} "
                + $"primary={snapshot.Primary?.RemainingPercent:0.##} "
                + $"secondary={snapshot.Secondary?.RemainingPercent:0.##}");
            if (_state.HasRealDualRing)
            {
                _state.DemoDualRing = false;
            }

            var targetOuter = OuterPercent(snapshot);
            var targetInner = InnerPercent(snapshot);
            if (!hadSnapshot)
            {
                _displayOuterPercent = targetOuter;
                _displayInnerPercent = targetInner;
            }
            else
            {
                if (_displayInnerPercent is null && targetInner is not null)
                {
                    _displayInnerPercent = targetInner;
                }
                StartAnimation();
            }
        }
        _state.IsRefreshing = false;
        _forceRender = true;
        UpdateOverlay(force: true);
    }

    private void ApplyErrors()
    {
        while (_errors.TryDequeue(out var error))
        {
            _state.ErrorMessage = error;
            Diagnostics.Write($"appServerError message={error}");
        }
        _state.IsRefreshing = false;
        UpdateOverlay(force: true);
    }

    private void StartAnimation()
    {
        if (_animationRunning)
        {
            return;
        }
        _animationRunning = true;
        NativeMethods.SetTimer(_messageWindow, AnimationTimer, 16, 0);
    }

    private void AdvanceAnimation()
    {
        var snapshot = _state.DisplaySnapshot;
        var outerTarget = OuterPercent(snapshot);
        var innerTarget = InnerPercent(snapshot);
        var outerDone = Approach(ref _displayOuterPercent, outerTarget);
        var innerDone = ApproachNullable(ref _displayInnerPercent, innerTarget);
        _forceRender = true;
        UpdateOverlay(force: true);
        if (outerDone && innerDone)
        {
            NativeMethods.KillTimer(_messageWindow, AnimationTimer);
            _animationRunning = false;
        }
    }

    private static bool Approach(ref double value, double target)
    {
        var difference = target - value;
        if (Math.Abs(difference) < 0.05)
        {
            value = target;
            return true;
        }
        value += difference * 0.18;
        return false;
    }

    private static bool ApproachNullable(ref double? value, double? target)
    {
        if (target is null)
        {
            value = null;
            return true;
        }
        var current = value ?? target.Value;
        var done = Approach(ref current, target.Value);
        value = current;
        return done;
    }

    private void UpdateOverlay(bool force = false)
    {
        if (!_clientRunning)
        {
            HideOverlays();
            return;
        }

        var located = _petLocator.Locate();
        if (located is not null)
        {
            _lastPet = located;
            Diagnostics.Write(
                $"pet frame={located.Frame.X:0.##},{located.Frame.Y:0.##},"
                + $"{located.Frame.Width:0.##},{located.Frame.Height:0.##} "
                + $"placement={located.Placement ?? "unknown"}");
        }
        var pet = located ?? _lastPet ?? DefaultPetLocation();
        var baseDiameter = UsageGeometry.BaseRingDiameter(
            pet.Frame,
            _state.RingPlacement,
            _state.AroundRingScale);
        var overlayDpiScale = Math.Max(1, pet.Scale);
        if (_state.ManualMove)
        {
            var destinationScale = Math.Max(1, NativeMethods.GetDpiForWindow(_ringWindow)) / 96.0;
            baseDiameter *= destinationScale / Math.Max(0.01, pet.Scale);
            overlayDpiScale = destinationScale;
        }
        var snapshot = _state.DisplaySnapshot;
        var hasDual = (snapshot?.Windows.Count ?? 0) > 1;
        var expansion = UsageGeometry.DualExpansion(
            hasDual,
            _state.RingPlacement,
            baseDiameter);
        var totalDiameter = baseDiameter + expansion;
        var canvasSize = Math.Max(64, (int)Math.Ceiling(totalDiameter + 16));

        PointD center;
        int originX;
        int originY;
        if (_state.ManualMove
            && NativeMethods.GetWindowRect(_ringWindow, out var currentRect)
            && currentRect.Width > 1)
        {
            var manualWorkArea = WorkAreaForWindow(_ringWindow) ?? pet.WorkArea;
            originX = (int)Math.Clamp(
                currentRect.left,
                manualWorkArea.Left,
                Math.Max(manualWorkArea.Left, manualWorkArea.Right - canvasSize));
            originY = (int)Math.Clamp(
                currentRect.top,
                manualWorkArea.Top,
                Math.Max(manualWorkArea.Top, manualWorkArea.Bottom - canvasSize));
            center = new PointD(originX + canvasSize / 2.0, originY + canvasSize / 2.0);
            pet = pet with { WorkArea = manualWorkArea };
        }
        else
        {
            center = UsageGeometry.RingCenter(
                pet.Frame,
                baseDiameter,
                _state.RingPlacement,
                pet.Placement);
            originX = (int)Math.Round(center.X - canvasSize / 2.0);
            originY = (int)Math.Round(center.Y - canvasSize / 2.0);
        }
        _lastRingCenter = center;
        _ringSize = totalDiameter;

        if (!_animationRunning)
        {
            _displayOuterPercent = OuterPercent(snapshot);
            _displayInnerPercent = InnerPercent(snapshot);
        }

        var key = string.Join(
            "|",
            originX,
            originY,
            canvasSize,
            totalDiameter.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
            expansion.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
            _state.RingPlacement,
            overlayDpiScale.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
            _displayOuterPercent.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
            _displayInnerPercent?.ToString("F2", System.Globalization.CultureInfo.InvariantCulture) ?? "-",
            _state.OuterRingColor,
            _state.InnerRingColor);
        if (force || _forceRender || key != _lastRingRenderKey)
        {
            _suppressMovePersistence = true;
            try
            {
                _renderer.RenderRing(
                    _ringWindow,
                    originX,
                    originY,
                    canvasSize,
                    totalDiameter,
                    expansion,
                    _state.RingPlacement,
                    overlayDpiScale,
                    _displayOuterPercent,
                    _displayInnerPercent,
                    _state.OuterRingColor,
                    _state.InnerRingColor);
            }
            finally
            {
                _suppressMovePersistence = false;
            }
            _lastRingRenderKey = key;
            _forceRender = false;
            Diagnostics.Write(
                $"ringPresented origin={originX},{originY} size={canvasSize} "
                + $"topmost=true layered=true clickThrough={!_state.ManualMove}");
        }
        else
        {
            NativeMethods.SetWindowPos(
                _ringWindow,
                NativeMethods.HWND_TOPMOST,
                0,
                0,
                0,
                0,
                NativeMethods.SWP_NOMOVE | NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOACTIVATE);
        }

        var showCard = _state.AlwaysVisible || CursorIsNear(center, totalDiameter);
        if (showCard)
        {
            ShowCard(pet.WorkArea, snapshot, overlayDpiScale);
        }
        else
        {
            NativeMethods.ShowWindow(_cardWindow, NativeMethods.SW_HIDE);
        }
    }

    private void ShowCard(
        RectD workArea,
        UsageSnapshot? snapshot,
        double dpiScale)
    {
        var logicalSize = UsageGeometry.CardSize(
            hasDualRing: (snapshot?.Windows.Count ?? 0) > 1,
            dpiScale);
        var width = Math.Max(
            1,
            (int)Math.Round(logicalSize.Width, MidpointRounding.AwayFromZero));
        var height = Math.Max(
            1,
            (int)Math.Round(logicalSize.Height, MidpointRounding.AwayFromZero));
        var origin = UsageGeometry.CardOrigin(
            _lastRingCenter,
            _ringSize,
            _state.RingPlacement,
            new SizeD(width, height),
            workArea,
            dpiScale,
            bottomPadding: UsageCardStyle.BottomPaddingExtension * Math.Max(1, dpiScale));
        _renderer.RenderCard(
            _cardWindow,
            (int)Math.Round(origin.X),
            (int)Math.Round(origin.Y),
            width,
            height,
            dpiScale,
            _state);
    }

    private static bool CursorIsNear(PointD center, double diameter)
    {
        if (!NativeMethods.GetCursorPos(out var cursor))
        {
            return false;
        }
        var deltaX = cursor.x - center.X;
        var deltaY = cursor.y - center.Y;
        return Math.Sqrt(deltaX * deltaX + deltaY * deltaY) <= diameter / 2 + 12;
    }

    private static PetLocation DefaultPetLocation()
    {
        var monitor = NativeMethods.MonitorFromPoint(
            new NativeMethods.POINT(0, 0),
            NativeMethods.MONITOR_DEFAULTTONEAREST);
        var info = new NativeMethods.MONITORINFOEX
        {
            cbSize = (uint)Marshal.SizeOf<NativeMethods.MONITORINFOEX>(),
            szDevice = ""
        };
        NativeMethods.GetMonitorInfoW(monitor, ref info);
        var work = new RectD(
            info.rcWork.left,
            info.rcWork.top,
            info.rcWork.Width,
            info.rcWork.Height);
        return new PetLocation(
            new RectD(work.Left + 70, work.Bottom - 170, 119, 129),
            work,
            null,
            1);
    }

    private static RectD? WorkAreaForWindow(nint hwnd)
    {
        var monitor = NativeMethods.MonitorFromWindow(
            hwnd,
            NativeMethods.MONITOR_DEFAULTTONEAREST);
        var info = new NativeMethods.MONITORINFOEX
        {
            cbSize = (uint)Marshal.SizeOf<NativeMethods.MONITORINFOEX>(),
            szDevice = ""
        };
        if (monitor == 0 || !NativeMethods.GetMonitorInfoW(monitor, ref info))
        {
            return null;
        }
        return new RectD(
            info.rcWork.left,
            info.rcWork.top,
            info.rcWork.Width,
            info.rcWork.Height);
    }

    private void HideOverlays()
    {
        NativeMethods.ShowWindow(_cardWindow, NativeMethods.SW_HIDE);
        NativeMethods.ShowWindow(_ringWindow, NativeMethods.SW_HIDE);
    }

    private void ApplyInteractionMode()
    {
        var style = NativeMethods.GetWindowLongPtrW(_ringWindow, NativeMethods.GWL_EXSTYLE).ToInt64();
        if (_state.ManualMove)
        {
            style &= ~NativeMethods.WS_EX_TRANSPARENT;
            if (_settingsStore.LoadManualPosition() is { } saved)
            {
                NativeMethods.SetWindowPos(
                    _ringWindow,
                    NativeMethods.HWND_TOPMOST,
                    (int)saved.X,
                    (int)saved.Y,
                    0,
                    0,
                    NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOACTIVATE);
            }
        }
        else
        {
            style |= NativeMethods.WS_EX_TRANSPARENT;
        }
        NativeMethods.SetWindowLongPtrW(_ringWindow, NativeMethods.GWL_EXSTYLE, new nint(style));
        _forceRender = true;
    }

    private void ShowTrayMenu()
    {
        var menu = NativeMethods.CreatePopupMenu();
        var placement = NativeMethods.CreatePopupMenu();
        var scale = NativeMethods.CreatePopupMenu();
        var colors = NativeMethods.CreatePopupMenu();
        try
        {
            AddItem(menu, CommandAlwaysVisible, "始终显示用量卡片", _state.AlwaysVisible);
            AddItem(menu, CommandManualMove, "自由拖动位置", _state.ManualMove);

            AddItem(placement, CommandPlacementAround, "围绕 pet", _state.RingPlacement == RingPlacement.Around);
            AddItem(placement, CommandPlacementLeft, "左侧（垂直居中）", _state.RingPlacement == RingPlacement.Left);
            AddItem(placement, CommandPlacementRight, "右侧（垂直居中）", _state.RingPlacement == RingPlacement.Right);
            NativeMethods.AppendMenuW(menu, NativeMethods.MF_POPUP, (nuint)placement, "圆环固定位置");

            AddItem(scale, CommandScale75, "75%", Math.Abs(_state.AroundRingScale - 0.75) < 0.01);
            AddItem(scale, CommandScale100, "100%", Math.Abs(_state.AroundRingScale - 1) < 0.01);
            AddItem(scale, CommandScale125, "125%", Math.Abs(_state.AroundRingScale - 1.25) < 0.01);
            AddItem(scale, CommandScale150, "150%", Math.Abs(_state.AroundRingScale - 1.5) < 0.01);
            NativeMethods.AppendMenuW(menu, NativeMethods.MF_POPUP, (nuint)scale, "围绕 pet 的圆环大小");

            AddItem(colors, CommandOuterColor, "外环颜色…");
            AddItem(colors, CommandInnerColor, "内环颜色…");
            NativeMethods.AppendMenuW(colors, NativeMethods.MF_SEPARATOR, 0, null);
            AddItem(colors, CommandDefaultColors, "恢复默认蓝绿");
            NativeMethods.AppendMenuW(menu, NativeMethods.MF_POPUP, (nuint)colors, "圆环颜色");

            AddItem(menu, CommandLaunchWithPet, "随 Codex 宠物启动", _state.LaunchWithCodexPet);
            AddItem(
                menu,
                CommandDemo,
                "演示双环",
                _state.DemoDualRing && _state.IsDualRingDemoAvailable,
                !_state.IsDualRingDemoAvailable);
            NativeMethods.AppendMenuW(menu, NativeMethods.MF_SEPARATOR, 0, null);
            AddItem(menu, CommandRefresh, "立即刷新");
            AddItem(menu, CommandRecalibrate, "重新检测宠物位置/大小");
            NativeMethods.AppendMenuW(menu, NativeMethods.MF_SEPARATOR, 0, null);
            AddItem(menu, CommandOpenReleases, "在浏览器查看 GitHub Releases…");
            NativeMethods.AppendMenuW(menu, NativeMethods.MF_SEPARATOR, 0, null);
            AddItem(menu, CommandQuit, "退出");

            NativeMethods.GetCursorPos(out var cursor);
            NativeMethods.SetForegroundWindow(_messageWindow);
            NativeMethods.TrackPopupMenuEx(
                menu,
                NativeMethods.TPM_RIGHTBUTTON | NativeMethods.TPM_BOTTOMALIGN,
                cursor.x,
                cursor.y,
                _messageWindow,
                0);
        }
        finally
        {
            NativeMethods.DestroyMenu(menu);
        }
    }

    private static void AddItem(
        nint menu,
        int command,
        string text,
        bool isChecked = false,
        bool isDisabled = false)
    {
        var flags = NativeMethods.MF_STRING
            | (isChecked ? NativeMethods.MF_CHECKED : 0)
            | (isDisabled ? NativeMethods.MF_GRAYED : 0);
        NativeMethods.AppendMenuW(menu, flags, (nuint)command, text);
    }

    private void OnCommand(int command)
    {
        switch (command)
        {
            case CommandAlwaysVisible:
                _state.AlwaysVisible = !_state.AlwaysVisible;
                break;
            case CommandManualMove:
                _state.ManualMove = !_state.ManualMove;
                ApplyInteractionMode();
                break;
            case CommandPlacementAround:
                _state.RingPlacement = RingPlacement.Around;
                break;
            case CommandPlacementLeft:
                _state.RingPlacement = RingPlacement.Left;
                break;
            case CommandPlacementRight:
                _state.RingPlacement = RingPlacement.Right;
                break;
            case CommandScale75:
                _state.AroundRingScale = 0.75;
                break;
            case CommandScale100:
                _state.AroundRingScale = 1;
                break;
            case CommandScale125:
                _state.AroundRingScale = 1.25;
                break;
            case CommandScale150:
                _state.AroundRingScale = 1.5;
                break;
            case CommandOuterColor:
                _state.OuterRingColor = ChooseColor(_state.OuterRingColor);
                break;
            case CommandInnerColor:
                _state.InnerRingColor = ChooseColor(_state.InnerRingColor);
                break;
            case CommandDefaultColors:
                _state.OuterRingColor = RingColor.DefaultOuter;
                _state.InnerRingColor = RingColor.DefaultInner;
                break;
            case CommandLaunchWithPet:
                _state.LaunchWithCodexPet = !_state.LaunchWithCodexPet;
                break;
            case CommandDemo when _state.IsDualRingDemoAvailable:
                _state.DemoDualRing = !_state.DemoDualRing;
                _displayOuterPercent = OuterPercent(_state.DisplaySnapshot);
                _displayInnerPercent = InnerPercent(_state.DisplaySnapshot);
                break;
            case CommandRefresh:
                _state.ErrorMessage = null;
                _state.IsRefreshing = true;
                _client.Refresh();
                break;
            case CommandRecalibrate:
                _lastPet = null;
                break;
            case CommandOpenReleases:
                OpenGitHubReleases();
                return;
            case CommandQuit:
                NativeMethods.PostMessageW(_messageWindow, NativeMethods.WM_CLOSE, 0, 0);
                return;
        }
        _settingsStore.Save(_state);
        UpdateClientLifecycle();
        _forceRender = true;
        UpdateOverlay(force: true);
    }

    private static void OpenGitHubReleases()
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = ProjectLinks.ReleasesUri.AbsoluteUri,
                UseShellExecute = true
            });
        }
        catch (InvalidOperationException error)
        {
            Diagnostics.Write($"openReleasesError message={error.Message}");
        }
        catch (Win32Exception error)
        {
            Diagnostics.Write($"openReleasesError message={error.Message}");
        }
    }

    private RingColor ChooseColor(RingColor current)
    {
        var customColors = Marshal.AllocHGlobal(16 * sizeof(uint));
        try
        {
            for (var index = 0; index < 16; index++)
            {
                Marshal.WriteInt32(customColors, index * sizeof(uint), 0x00FFFFFF);
            }
            var choose = new NativeMethods.CHOOSECOLOR
            {
                lStructSize = (uint)Marshal.SizeOf<NativeMethods.CHOOSECOLOR>(),
                hwndOwner = _messageWindow,
                rgbResult = (uint)(current.Red | (current.Green << 8) | (current.Blue << 16)),
                lpCustColors = customColors,
                Flags = NativeMethods.CC_FULLOPEN | NativeMethods.CC_RGBINIT
            };
            if (!NativeMethods.ChooseColorW(ref choose))
            {
                return current;
            }
            return new RingColor(
                (byte)(choose.rgbResult & 0xFF),
                (byte)((choose.rgbResult >> 8) & 0xFF),
                (byte)((choose.rgbResult >> 16) & 0xFF));
        }
        finally
        {
            Marshal.FreeHGlobal(customColors);
        }
    }

    private static double OuterPercent(UsageSnapshot? snapshot)
    {
        return snapshot?.Windows.FirstOrDefault(window => !window.IsWeekly)?.RemainingPercent
            ?? snapshot?.Windows.FirstOrDefault()?.RemainingPercent
            ?? 0;
    }

    private static double? InnerPercent(UsageSnapshot? snapshot)
    {
        var windows = snapshot?.Windows;
        if (windows is null || !windows.Any(window => !window.IsWeekly))
        {
            return null;
        }
        return windows.FirstOrDefault(window => window.IsWeekly)?.RemainingPercent;
    }
}
