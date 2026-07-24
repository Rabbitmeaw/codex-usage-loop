using System.Runtime.InteropServices;

namespace CodexUsageLoop.Windows;

internal static class NativeMethods
{
    internal const int CW_USEDEFAULT = unchecked((int)0x80000000);
    internal const uint WS_POPUP = 0x80000000;
    internal const uint WS_EX_TOPMOST = 0x00000008;
    internal const uint WS_EX_TOOLWINDOW = 0x00000080;
    internal const uint WS_EX_LAYERED = 0x00080000;
    internal const uint WS_EX_TRANSPARENT = 0x00000020;
    internal const uint WS_EX_NOACTIVATE = 0x08000000;

    internal const int GWL_EXSTYLE = -20;
    internal const int HTCAPTION = 2;
    internal const int HTTRANSPARENT = -1;
    internal const int WM_DESTROY = 0x0002;
    internal const int WM_MOVE = 0x0003;
    internal const int WM_CLOSE = 0x0010;
    internal const int WM_NCHITTEST = 0x0084;
    internal const int WM_COMMAND = 0x0111;
    internal const int WM_TIMER = 0x0113;
    internal const int WM_ENDSESSION = 0x0016;
    internal const int WM_DPICHANGED = 0x02E0;
    internal const int WM_APP = 0x8000;
    internal const int WM_TRAYICON = WM_APP + 1;
    internal const int WM_APP_SNAPSHOT = WM_APP + 2;
    internal const int WM_APP_ERROR = WM_APP + 3;
    internal const int WM_LBUTTONUP = 0x0202;
    internal const int WM_RBUTTONUP = 0x0205;
    internal const int WM_CONTEXTMENU = 0x007B;

    internal const uint SWP_NOSIZE = 0x0001;
    internal const uint SWP_NOMOVE = 0x0002;
    internal const uint SWP_NOACTIVATE = 0x0010;
    internal const uint SWP_SHOWWINDOW = 0x0040;
    internal const int SW_HIDE = 0;
    internal const int SW_SHOWNOACTIVATE = 4;
    internal static readonly nint HWND_TOPMOST = new(-1);

    internal const uint ULW_ALPHA = 0x00000002;
    internal const byte AC_SRC_OVER = 0;
    internal const byte AC_SRC_ALPHA = 1;

    internal const uint NIM_ADD = 0;
    internal const uint NIM_MODIFY = 1;
    internal const uint NIM_DELETE = 2;
    internal const uint NIM_SETVERSION = 4;
    internal const uint NIF_MESSAGE = 0x1;
    internal const uint NIF_ICON = 0x2;
    internal const uint NIF_TIP = 0x4;
    internal const uint NOTIFYICON_VERSION_4 = 4;

    internal const uint MF_STRING = 0;
    internal const uint MF_SEPARATOR = 0x800;
    internal const uint MF_POPUP = 0x10;
    internal const uint MF_CHECKED = 0x8;
    internal const uint MF_GRAYED = 0x1;
    internal const uint TPM_RIGHTBUTTON = 0x0002;
    internal const uint TPM_BOTTOMALIGN = 0x0020;

    internal const uint MONITOR_DEFAULTTONEAREST = 2;
    internal const uint BI_RGB = 0;
    internal const uint DIB_RGB_COLORS = 0;
    internal const uint CC_FULLOPEN = 0x2;
    internal const uint CC_RGBINIT = 0x1;

    internal const int PixelFormat32bppPARGB = 0x000E200B;
    internal const int SmoothingModeAntiAlias = 4;
    internal const int TextRenderingHintAntiAliasGridFit = 3;
    internal const int UnitPixel = 2;
    internal const int FontStyleRegular = 0;
    internal const int FontStyleBold = 1;

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    internal delegate nint WindowProc(nint hwnd, uint message, nuint wParam, nint lParam);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal delegate bool MonitorEnumProc(nint monitor, nint dc, ref RECT rect, nint data);

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal delegate bool WindowEnumProc(nint hwnd, nint data);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct WNDCLASSEX
    {
        internal uint cbSize;
        internal uint style;
        internal WindowProc lpfnWndProc;
        internal int cbClsExtra;
        internal int cbWndExtra;
        internal nint hInstance;
        internal nint hIcon;
        internal nint hCursor;
        internal nint hbrBackground;
        [MarshalAs(UnmanagedType.LPWStr)] internal string? lpszMenuName;
        [MarshalAs(UnmanagedType.LPWStr)] internal string lpszClassName;
        internal nint hIconSm;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct POINT
    {
        internal int x;
        internal int y;
        internal POINT(int x, int y) { this.x = x; this.y = y; }
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct SIZE
    {
        internal int cx;
        internal int cy;
        internal SIZE(int width, int height) { cx = width; cy = height; }
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct RECT
    {
        internal int left;
        internal int top;
        internal int right;
        internal int bottom;
        internal int Width => right - left;
        internal int Height => bottom - top;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct BLENDFUNCTION
    {
        internal byte BlendOp;
        internal byte BlendFlags;
        internal byte SourceConstantAlpha;
        internal byte AlphaFormat;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct RTL_OSVERSIONINFOEX
    {
        internal uint dwOSVersionInfoSize;
        internal uint dwMajorVersion;
        internal uint dwMinorVersion;
        internal uint dwBuildNumber;
        internal uint dwPlatformId;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        internal string szCSDVersion;
        internal ushort wServicePackMajor;
        internal ushort wServicePackMinor;
        internal ushort wSuiteMask;
        internal byte wProductType;
        internal byte wReserved;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct BITMAPINFOHEADER
    {
        internal uint biSize;
        internal int biWidth;
        internal int biHeight;
        internal ushort biPlanes;
        internal ushort biBitCount;
        internal uint biCompression;
        internal uint biSizeImage;
        internal int biXPelsPerMeter;
        internal int biYPelsPerMeter;
        internal uint biClrUsed;
        internal uint biClrImportant;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct BITMAPINFO
    {
        internal BITMAPINFOHEADER bmiHeader;
        internal uint bmiColors;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct MONITORINFOEX
    {
        internal uint cbSize;
        internal RECT rcMonitor;
        internal RECT rcWork;
        internal uint dwFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        internal string szDevice;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct NOTIFYICONDATA
    {
        internal uint cbSize;
        internal nint hWnd;
        internal uint uID;
        internal uint uFlags;
        internal uint uCallbackMessage;
        internal nint hIcon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        internal string szTip;
        internal uint dwState;
        internal uint dwStateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
        internal string szInfo;
        internal uint uVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        internal string szInfoTitle;
        internal uint dwInfoFlags;
        internal Guid guidItem;
        internal nint hBalloonIcon;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct ICONINFO
    {
        [MarshalAs(UnmanagedType.Bool)] internal bool fIcon;
        internal uint xHotspot;
        internal uint yHotspot;
        internal nint hbmMask;
        internal nint hbmColor;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct CHOOSECOLOR
    {
        internal uint lStructSize;
        internal nint hwndOwner;
        internal nint hInstance;
        internal uint rgbResult;
        internal nint lpCustColors;
        internal uint Flags;
        internal nint lCustData;
        internal nint lpfnHook;
        internal nint lpTemplateName;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct GdiplusStartupInput
    {
        internal uint GdiplusVersion;
        internal nint DebugEventCallback;
        [MarshalAs(UnmanagedType.Bool)] internal bool SuppressBackgroundThread;
        [MarshalAs(UnmanagedType.Bool)] internal bool SuppressExternalCodecs;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct GpRectF
    {
        internal float X;
        internal float Y;
        internal float Width;
        internal float Height;
        internal GpRectF(float x, float y, float width, float height)
        {
            X = x; Y = y; Width = width; Height = height;
        }
    }

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern ushort RegisterClassExW(ref WNDCLASSEX windowClass);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern nint CreateWindowExW(
        uint extendedStyle, string className, string windowName, uint style,
        int x, int y, int width, int height, nint parent, nint menu, nint instance, nint parameter);

    [DllImport("user32.dll")]
    internal static extern nint DefWindowProcW(nint hwnd, uint message, nuint wParam, nint lParam);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DestroyWindow(nint hwnd);

    [DllImport("user32.dll")]
    internal static extern void PostQuitMessage(int exitCode);

    [DllImport("user32.dll")]
    internal static extern int GetMessageW(out MSG message, nint hwnd, uint min, uint max);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool TranslateMessage(ref MSG message);

    [DllImport("user32.dll")]
    internal static extern nint DispatchMessageW(ref MSG message);

    [StructLayout(LayoutKind.Sequential)]
    internal struct MSG
    {
        internal nint hwnd;
        internal uint message;
        internal nuint wParam;
        internal nint lParam;
        internal uint time;
        internal POINT pt;
        internal uint lPrivate;
    }

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetProcessDpiAwarenessContext(nint dpiContext);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ShowWindow(nint hwnd, int command);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetWindowPos(
        nint hwnd, nint insertAfter, int x, int y, int width, int height, uint flags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetWindowRect(nint hwnd, out RECT rect);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    internal static extern nuint SetTimer(nint hwnd, nuint id, uint milliseconds, nint callback);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool KillTimer(nint hwnd, nuint id);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool PostMessageW(nint hwnd, uint message, nuint wParam, nint lParam);

    [DllImport("user32.dll")]
    internal static extern nint MonitorFromPoint(POINT point, uint flags);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool EnumDisplayMonitors(
        nint dc, nint clip, MonitorEnumProc callback, nint data);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool EnumWindows(WindowEnumProc callback, nint data);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool IsWindowVisible(nint hwnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    internal static extern int GetWindowTextW(nint hwnd, char[] text, int length);

    [DllImport("user32.dll")]
    internal static extern uint GetWindowThreadProcessId(nint hwnd, out uint processId);

    [DllImport("user32.dll")]
    internal static extern nint MonitorFromWindow(nint hwnd, uint flags);

    [DllImport("user32.dll")]
    internal static extern uint GetDpiForWindow(nint hwnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool GetMonitorInfoW(nint monitor, ref MONITORINFOEX info);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool UpdateLayeredWindow(
        nint hwnd, nint destinationDc, ref POINT destinationPoint, ref SIZE size,
        nint sourceDc, ref POINT sourcePoint, uint colorKey, ref BLENDFUNCTION blend, uint flags);

    [DllImport("user32.dll")]
    internal static extern nint GetDC(nint hwnd);

    [DllImport("user32.dll")]
    internal static extern int ReleaseDC(nint hwnd, nint dc);

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    internal static extern nint GetWindowLongPtrW(nint hwnd, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    internal static extern nint SetWindowLongPtrW(nint hwnd, int index, nint value);

    [DllImport("user32.dll", SetLastError = true)]
    internal static extern nint CreateIconIndirect(ref ICONINFO iconInfo);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DestroyIcon(nint icon);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool SetForegroundWindow(nint hwnd);

    [DllImport("user32.dll")]
    internal static extern nint CreatePopupMenu();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool AppendMenuW(nint menu, uint flags, nuint id, string? text);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool TrackPopupMenuEx(
        nint menu, uint flags, int x, int y, nint hwnd, nint parameters);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DestroyMenu(nint menu);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool Shell_NotifyIconW(uint message, ref NOTIFYICONDATA data);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    internal static extern nint GetModuleHandleW(string? moduleName);

    [DllImport("gdi32.dll")]
    internal static extern nint CreateCompatibleDC(nint dc);

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DeleteDC(nint dc);

    [DllImport("gdi32.dll")]
    internal static extern nint SelectObject(nint dc, nint obj);

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool DeleteObject(nint obj);

    [DllImport("gdi32.dll")]
    internal static extern nint CreateDIBSection(
        nint dc, ref BITMAPINFO info, uint usage, out nint bits, nint section, uint offset);

    [DllImport("gdi32.dll")]
    internal static extern nint CreateBitmap(int width, int height, uint planes, uint bitCount, nint bits);

    [DllImport("comdlg32.dll", CharSet = CharSet.Unicode)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static extern bool ChooseColorW(ref CHOOSECOLOR chooseColor);

    [DllImport("gdiplus.dll")]
    internal static extern int GdiplusStartup(out nuint token, ref GdiplusStartupInput input, nint output);

    [DllImport("gdiplus.dll")]
    internal static extern void GdiplusShutdown(nuint token);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipCreateBitmapFromScan0(
        int width, int height, int stride, int pixelFormat, nint scan0, out nint bitmap);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipGetImageGraphicsContext(nint image, out nint graphics);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDeleteGraphics(nint graphics);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDisposeImage(nint image);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipGraphicsClear(nint graphics, uint color);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipSetSmoothingMode(nint graphics, int mode);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipSetTextRenderingHint(nint graphics, int mode);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipCreatePen1(uint color, float width, int unit, out nint pen);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDeletePen(nint pen);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDrawArc(
        nint graphics, nint pen, float x, float y, float width, float height, float start, float sweep);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipCreateSolidFill(uint color, out nint brush);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDeleteBrush(nint brush);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipFillEllipse(
        nint graphics, nint brush, float x, float y, float width, float height);

    [DllImport("gdiplus.dll", CharSet = CharSet.Unicode)]
    internal static extern int GdipCreateFontFamilyFromName(string name, nint collection, out nint family);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDeleteFontFamily(nint family);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipCreateFont(
        nint family, float emSize, int style, int unit, out nint font);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDeleteFont(nint font);

    [DllImport("gdiplus.dll", CharSet = CharSet.Unicode)]
    internal static extern int GdipDrawString(
        nint graphics, string text, int length, nint font, ref GpRectF layout,
        nint format, nint brush);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipCreatePath(int fillMode, out nint path);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDeletePath(nint path);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipAddPathArc(
        nint path, float x, float y, float width, float height, float start, float sweep);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipAddPathRectangle(
        nint path, float x, float y, float width, float height);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipClosePathFigure(nint path);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipFillPath(nint graphics, nint brush, nint path);

    [DllImport("gdiplus.dll")]
    internal static extern int GdipDrawPath(nint graphics, nint pen, nint path);

    [DllImport("ntdll.dll")]
    internal static extern int RtlGetVersion(ref RTL_OSVERSIONINFOEX versionInformation);
}
