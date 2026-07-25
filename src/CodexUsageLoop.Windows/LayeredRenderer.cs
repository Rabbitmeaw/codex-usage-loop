using CodexUsageLoop.Core;
using System.Runtime.InteropServices;

namespace CodexUsageLoop.Windows;

internal sealed class GdiPlusRuntime : IDisposable
{
    private nuint _token;

    internal GdiPlusRuntime()
    {
        var input = new NativeMethods.GdiplusStartupInput
        {
            GdiplusVersion = 1
        };
        Check(NativeMethods.GdiplusStartup(out _token, ref input, 0));
    }

    public void Dispose()
    {
        if (_token != 0)
        {
            NativeMethods.GdiplusShutdown(_token);
            _token = 0;
        }
    }

    internal static void Check(int status)
    {
        if (status != 0)
        {
            throw new InvalidOperationException($"GDI+ operation failed ({status}).");
        }
    }
}

internal sealed class LayeredSurface : IDisposable
{
    private readonly nint _oldBitmap;
    private nint _image;
    private nint _graphics;

    internal int Width { get; }
    internal int Height { get; }
    internal nint Bitmap { get; private set; }
    internal nint Bits { get; }
    internal nint MemoryDc { get; private set; }
    internal nint Graphics => _graphics;

    internal LayeredSurface(int width, int height)
    {
        Width = Math.Max(1, width);
        Height = Math.Max(1, height);
        var screenDc = NativeMethods.GetDC(0);
        try
        {
            MemoryDc = NativeMethods.CreateCompatibleDC(screenDc);
            var info = new NativeMethods.BITMAPINFO
            {
                bmiHeader = new NativeMethods.BITMAPINFOHEADER
                {
                    biSize = (uint)Marshal.SizeOf<NativeMethods.BITMAPINFOHEADER>(),
                    biWidth = Width,
                    biHeight = -Height,
                    biPlanes = 1,
                    biBitCount = 32,
                    biCompression = NativeMethods.BI_RGB,
                    biSizeImage = (uint)(Width * Height * 4)
                }
            };
            Bitmap = NativeMethods.CreateDIBSection(
                screenDc, ref info, NativeMethods.DIB_RGB_COLORS, out var bits, 0, 0);
            Bits = bits;
            if (Bitmap == 0 || Bits == 0 || MemoryDc == 0)
            {
                throw new InvalidOperationException("Unable to create 32-bit DIB surface.");
            }

            _oldBitmap = NativeMethods.SelectObject(MemoryDc, Bitmap);
            GdiPlusRuntime.Check(NativeMethods.GdipCreateBitmapFromScan0(
                Width, Height, Width * 4, NativeMethods.PixelFormat32bppPARGB, Bits, out _image));
            GdiPlusRuntime.Check(NativeMethods.GdipGetImageGraphicsContext(_image, out _graphics));
            GdiPlusRuntime.Check(NativeMethods.GdipSetSmoothingMode(
                _graphics, NativeMethods.SmoothingModeAntiAlias));
            GdiPlusRuntime.Check(NativeMethods.GdipSetTextRenderingHint(
                _graphics, NativeMethods.TextRenderingHintAntiAliasGridFit));
        }
        finally
        {
            if (screenDc != 0)
            {
                NativeMethods.ReleaseDC(0, screenDc);
            }
        }
    }

    internal void Clear()
    {
        GdiPlusRuntime.Check(NativeMethods.GdipGraphicsClear(_graphics, 0));
    }

    public void Dispose()
    {
        if (_graphics != 0)
        {
            NativeMethods.GdipDeleteGraphics(_graphics);
            _graphics = 0;
        }
        if (_image != 0)
        {
            NativeMethods.GdipDisposeImage(_image);
            _image = 0;
        }
        if (MemoryDc != 0)
        {
            NativeMethods.SelectObject(MemoryDc, _oldBitmap);
            NativeMethods.DeleteDC(MemoryDc);
            MemoryDc = 0;
        }
        if (Bitmap != 0)
        {
            NativeMethods.DeleteObject(Bitmap);
            Bitmap = 0;
        }
    }
}

internal sealed class LayeredRenderer
{
    private LayeredSurface? _ringSurface;
    private LayeredSurface? _cardSurface;

    internal void RenderRing(
        nint hwnd,
        int x,
        int y,
        int canvasSize,
        double totalRingDiameter,
        double dualExpansion,
        RingPlacement placement,
        double dpiScale,
        double outerPercent,
        double? innerPercent,
        RingColor outerColor,
        RingColor innerColor)
    {
        _ringSurface = EnsureSurface(_ringSurface, canvasSize, canvasSize);
        var surface = _ringSurface;
        surface.Clear();

        var center = canvasSize / 2f;
        var outerDiameter = (float)Math.Max(1, totalRingDiameter - 18);
        var compact = placement != RingPlacement.Around;
        DrawRing(
            surface.Graphics,
            center,
            outerDiameter,
            outerPercent,
            outerColor,
            compact,
            dpiScale: dpiScale);
        if (innerPercent is not null)
        {
            DrawRing(
                surface.Graphics,
                center,
                Math.Max(1, outerDiameter - (float)dualExpansion),
                innerPercent.Value,
                innerColor,
                compact,
                dpiScale: dpiScale);
        }

        Present(hwnd, surface, x, y);
    }

    internal void RenderCard(
        nint hwnd,
        int x,
        int y,
        int width,
        int height,
        double dpiScale,
        UsageState state)
    {
        _cardSurface = EnsureSurface(_cardSurface, width, height);
        var surface = _cardSurface;
        surface.Clear();

        var scale = (float)Math.Max(1, dpiScale);
        var metrics = UsageCardStyle.Metrics(dpiScale, WindowsVersion.BuildNumber);
        var borderWidth = (float)metrics.BorderWidth;
        DrawRoundedRectangle(
            surface.Graphics,
            borderWidth / 2,
            borderWidth / 2,
            width - borderWidth,
            height - borderWidth,
            (float)metrics.CornerRadius,
            0xFF202020,
            0x18FFFFFF,
            borderWidth);
        var windows = state.DisplaySnapshot?.Windows ?? Array.Empty<UsageWindow>();
        var yOffset = 8 * scale;
        foreach (var window in windows.Take(2))
        {
            var hasShort = windows.Any(item => !item.IsWeekly);
            var color = window.IsWeekly && hasShort ? state.InnerRingColor : state.OuterRingColor;
            DrawDot(surface.Graphics, 10 * scale, yOffset + 7 * scale, 6 * scale, color);
            var reset = window.ResetsAt is null ? "" : $" · {Countdown(window.ResetsAt.Value)}";
            DrawText(
                surface.Graphics,
                $"{window.Label}  {window.RemainingPercent:0}% 剩余{reset}",
                20 * scale,
                yOffset + (float)metrics.PrimaryTextTopOffset,
                width - 27 * scale,
                18 * scale,
                (float)metrics.PrimaryTextSize,
                true,
                UsageCardStyle.PrimaryFontFamily,
                0xD9FFFFFF);
            yOffset += 19 * scale;
        }

        DrawText(
            surface.Graphics,
            state.StatusText,
            10 * scale,
            (float)UsageCardStyle.StatusTextTop(height, dpiScale),
            width - 20 * scale,
            14 * scale,
            (float)metrics.SecondaryTextSize,
            false,
            UsageCardStyle.SecondaryFontFamily,
            UsageCardStyle.SecondaryTextColor);
        Present(hwnd, surface, x, y);
    }

    internal nint CreateTrayIcon()
    {
        using var surface = new LayeredSurface(32, 32);
        surface.Clear();
        DrawRing(surface.Graphics, 16, 24, 84, RingColor.DefaultOuter, false, 4);
        DrawRing(surface.Graphics, 16, 16, 64, RingColor.DefaultInner, false, 3);
        var mask = NativeMethods.CreateBitmap(32, 32, 1, 1, 0);
        try
        {
            var info = new NativeMethods.ICONINFO
            {
                fIcon = true,
                hbmColor = surface.Bitmap,
                hbmMask = mask
            };
            return NativeMethods.CreateIconIndirect(ref info);
        }
        finally
        {
            if (mask != 0)
            {
                NativeMethods.DeleteObject(mask);
            }
        }
    }

    internal void Dispose()
    {
        _ringSurface?.Dispose();
        _ringSurface = null;
        _cardSurface?.Dispose();
        _cardSurface = null;
    }

    private static LayeredSurface EnsureSurface(LayeredSurface? existing, int width, int height)
    {
        if (existing is not null && existing.Width == width && existing.Height == height)
        {
            return existing;
        }

        existing?.Dispose();
        return new LayeredSurface(width, height);
    }

    private static void Present(nint hwnd, LayeredSurface surface, int x, int y)
    {
        var screenDc = NativeMethods.GetDC(0);
        try
        {
            var destination = new NativeMethods.POINT(x, y);
            var source = new NativeMethods.POINT(0, 0);
            var size = new NativeMethods.SIZE(surface.Width, surface.Height);
            var blend = new NativeMethods.BLENDFUNCTION
            {
                BlendOp = NativeMethods.AC_SRC_OVER,
                SourceConstantAlpha = 255,
                AlphaFormat = NativeMethods.AC_SRC_ALPHA
            };
            if (!NativeMethods.UpdateLayeredWindow(
                hwnd, screenDc, ref destination, ref size,
                surface.MemoryDc, ref source, 0, ref blend, NativeMethods.ULW_ALPHA))
            {
                throw new InvalidOperationException("UpdateLayeredWindow failed.");
            }
            NativeMethods.SetWindowPos(
                hwnd, NativeMethods.HWND_TOPMOST, 0, 0, 0, 0,
                NativeMethods.SWP_NOMOVE | NativeMethods.SWP_NOSIZE
                | NativeMethods.SWP_NOACTIVATE | NativeMethods.SWP_SHOWWINDOW);
        }
        finally
        {
            NativeMethods.ReleaseDC(0, screenDc);
        }
    }

    private static void DrawRing(
        nint graphics,
        float center,
        float diameter,
        double percent,
        RingColor color,
        bool compact,
        float? fixedLineWidth = null,
        double dpiScale = 1)
    {
        var lineWidth = fixedLineWidth
            ?? (float)UsageRingStyle.LineWidth(diameter, compact, dpiScale);
        var x = center - diameter / 2;
        var y = center - diameter / 2;
        DrawArc(graphics, x, y, diameter, lineWidth, color, 61, -90, 360);
        DrawArc(
            graphics, x, y, diameter, lineWidth, color, 242,
            -90, (float)(360 * Math.Clamp(percent, 0, 100) / 100));
    }

    private static void DrawArc(
        nint graphics,
        float x,
        float y,
        float diameter,
        float lineWidth,
        RingColor color,
        byte alpha,
        float start,
        float sweep)
    {
        var penColor = Argb(alpha, color);
        GdiPlusRuntime.Check(NativeMethods.GdipCreatePen1(
            penColor, lineWidth, NativeMethods.UnitPixel, out var pen));
        try
        {
            GdiPlusRuntime.Check(NativeMethods.GdipDrawArc(
                graphics, pen, x, y, diameter, diameter, start, sweep));
        }
        finally
        {
            NativeMethods.GdipDeletePen(pen);
        }
    }

    private static void DrawDot(
        nint graphics,
        float x,
        float y,
        float diameter,
        RingColor color)
    {
        GdiPlusRuntime.Check(NativeMethods.GdipCreateSolidFill(
            Argb(255, color), out var brush));
        try
        {
            GdiPlusRuntime.Check(NativeMethods.GdipFillEllipse(
                graphics, brush, x, y, diameter, diameter));
        }
        finally
        {
            NativeMethods.GdipDeleteBrush(brush);
        }
    }

    private static void DrawText(
        nint graphics,
        string text,
        float x,
        float y,
        float width,
        float height,
        float size,
        bool bold,
        string preferredFontFamily,
        uint color)
    {
        var status = NativeMethods.GdipCreateFontFamilyFromName(
            preferredFontFamily, 0, out var family);
        if (status != 0)
        {
            GdiPlusRuntime.Check(NativeMethods.GdipCreateFontFamilyFromName(
                UsageCardStyle.FallbackFontFamily, 0, out family));
        }
        try
        {
            GdiPlusRuntime.Check(NativeMethods.GdipCreateFont(
                family,
                size,
                bold ? NativeMethods.FontStyleBold : NativeMethods.FontStyleRegular,
                NativeMethods.UnitPixel,
                out var font));
            try
            {
                GdiPlusRuntime.Check(NativeMethods.GdipCreateSolidFill(color, out var brush));
                try
                {
                    var layout = new NativeMethods.GpRectF(x, y, width, height);
                    GdiPlusRuntime.Check(NativeMethods.GdipDrawString(
                        graphics, text, text.Length, font, ref layout, 0, brush));
                }
                finally
                {
                    NativeMethods.GdipDeleteBrush(brush);
                }
            }
            finally
            {
                NativeMethods.GdipDeleteFont(font);
            }
        }
        finally
        {
            NativeMethods.GdipDeleteFontFamily(family);
        }
    }

    private static void DrawRoundedRectangle(
        nint graphics,
        float x,
        float y,
        float width,
        float height,
        float radius,
        uint fillColor,
        uint borderColor,
        float borderWidth)
    {
        GdiPlusRuntime.Check(NativeMethods.GdipCreatePath(0, out var path));
        try
        {
            if (radius <= 0)
            {
                GdiPlusRuntime.Check(NativeMethods.GdipAddPathRectangle(
                    path, x, y, width, height));
            }
            else
            {
                var diameter = radius * 2;
                GdiPlusRuntime.Check(NativeMethods.GdipAddPathArc(path, x, y, diameter, diameter, 180, 90));
                GdiPlusRuntime.Check(NativeMethods.GdipAddPathArc(path, x + width - diameter, y, diameter, diameter, 270, 90));
                GdiPlusRuntime.Check(NativeMethods.GdipAddPathArc(path, x + width - diameter, y + height - diameter, diameter, diameter, 0, 90));
                GdiPlusRuntime.Check(NativeMethods.GdipAddPathArc(path, x, y + height - diameter, diameter, diameter, 90, 90));
            }
            GdiPlusRuntime.Check(NativeMethods.GdipClosePathFigure(path));

            GdiPlusRuntime.Check(NativeMethods.GdipCreateSolidFill(fillColor, out var brush));
            try
            {
                GdiPlusRuntime.Check(NativeMethods.GdipFillPath(graphics, brush, path));
            }
            finally
            {
                NativeMethods.GdipDeleteBrush(brush);
            }

            GdiPlusRuntime.Check(NativeMethods.GdipCreatePen1(
                borderColor, borderWidth, NativeMethods.UnitPixel, out var pen));
            try
            {
                GdiPlusRuntime.Check(NativeMethods.GdipDrawPath(graphics, pen, path));
            }
            finally
            {
                NativeMethods.GdipDeletePen(pen);
            }
        }
        finally
        {
            NativeMethods.GdipDeletePath(path);
        }
    }

    private static string Countdown(DateTimeOffset reset)
    {
        var seconds = Math.Max(0, (long)(reset - DateTimeOffset.Now).TotalSeconds);
        if (seconds >= 86_400)
        {
            return $"{seconds / 86_400}天后";
        }
        if (seconds >= 3_600)
        {
            return $"{seconds / 3_600}小时后";
        }
        return $"{Math.Max(1, seconds / 60)}分钟后";
    }

    private static uint Argb(byte alpha, RingColor color) =>
        ((uint)alpha << 24) | ((uint)color.Red << 16) | ((uint)color.Green << 8) | color.Blue;
}
