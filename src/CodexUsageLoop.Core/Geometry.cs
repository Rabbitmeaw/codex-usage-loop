namespace CodexUsageLoop.Core;

public readonly record struct PointD(double X, double Y);
public readonly record struct SizeD(double Width, double Height);

public readonly record struct RectD(double X, double Y, double Width, double Height)
{
    public double Left => X;
    public double Top => Y;
    public double Right => X + Width;
    public double Bottom => Y + Height;
    public double CenterX => X + Width / 2;
    public double CenterY => Y + Height / 2;
    public bool IsValid => double.IsFinite(X) && double.IsFinite(Y)
        && double.IsFinite(Width) && double.IsFinite(Height)
        && Width > 0 && Height > 0;
}

public static class UsageGeometry
{
    public const double MinimumAroundScale = 0.25;
    public const double MaximumAroundScale = 2.50;
    public const double AroundDiameterRatio = 194.35 / 129.0;
    public const double AroundDualExpansionRatio = 22.0 / 194.35;
    public const double AnchoredFallbackAroundDiameterRatio = 2.0 / 3.0;
    public const double AnchoredFallbackTopClearance = 16;

    public static double ClampAroundScale(double value) =>
        Math.Clamp(value, MinimumAroundScale, MaximumAroundScale);

    public static RectD EstimateMascot(RectD container, RectD display, string? placement)
    {
        var width = container.Width * (119.0 / 356.0);
        var height = container.Height * (129.0 / 320.0);
        double y;
        if (placement?.Contains("top", StringComparison.OrdinalIgnoreCase) == true)
        {
            y = container.Bottom - height;
        }
        else if (placement?.Contains("bottom", StringComparison.OrdinalIgnoreCase) == true)
        {
            y = container.Top;
        }
        else
        {
            y = container.Top <= display.Top + display.Height * 0.6
                ? container.Top
                : container.Bottom - height;
        }

        return new RectD(container.CenterX - width / 2, y, width, height);
    }

    public static double BaseRingDiameter(RectD pet, RingPlacement placement, double aroundScale)
    {
        if (placement == RingPlacement.Around)
        {
            return Math.Max(pet.Width, pet.Height)
                * AroundDiameterRatio
                * ClampAroundScale(aroundScale);
        }

        var sideReference = Math.Max(104, (Math.Max(pet.Width, pet.Height) + 40) * 1.15);
        return Math.Max(48, sideReference * 0.30);
    }

    public static double FallbackAroundDiameter(double estimatedDiameter, bool isAnchoredFallback) =>
        isAnchoredFallback
            ? estimatedDiameter * AnchoredFallbackAroundDiameterRatio
            : estimatedDiameter;

    public static double DualExpansion(bool hasDualRing, RingPlacement placement, double baseDiameter)
    {
        if (!hasDualRing)
        {
            return 0;
        }

        return placement == RingPlacement.Around
            ? baseDiameter * AroundDualExpansionRatio
            : 14;
    }

    public static SizeD CardSize(bool hasDualRing, double dpiScale)
    {
        var scale = Math.Max(1, dpiScale);
        return new SizeD(
            190 * scale,
            (hasDualRing ? 74 : 58) * scale);
    }

    public static PointD RingCenter(
        RectD pet,
        double baseRingDiameter,
        RingPlacement placement,
        string? codexPlacement = null,
        RectD? fallbackContainer = null,
        RectD? fallbackVisibleArea = null,
        bool isAnchoredFallback = false,
        double fallbackTopClearance = AnchoredFallbackTopClearance)
    {
        var taskCardAbove = codexPlacement?.Contains(
            "top",
            StringComparison.OrdinalIgnoreCase) == true;
        var sideY = pet.CenterY + (taskCardAbove ? baseRingDiameter * 0.45 : 0);
        if (placement == RingPlacement.Around
            && isAnchoredFallback
            && fallbackContainer is { } container)
        {
            var topAlignedY = pet.Bottom + fallbackTopClearance - baseRingDiameter / 2;
            var isAtHorizontalEdge = fallbackVisibleArea is { } visible
                && (container.Left <= visible.Left || container.Right >= visible.Right);
            return new PointD(isAtHorizontalEdge ? pet.CenterX : container.CenterX, topAlignedY);
        }

        return placement switch
        {
            RingPlacement.Left => new PointD(
                pet.Left - baseRingDiameter * 0.56,
                sideY),
            RingPlacement.Right => new PointD(
                pet.Right + baseRingDiameter * 0.56,
                sideY),
            _ => new PointD(pet.CenterX, pet.CenterY)
        };
    }

    public static PointD CardOrigin(
        PointD ringCenter,
        double ringSize,
        RingPlacement placement,
        SizeD cardSize,
        RectD workArea,
        double dpiScale = 1,
        double bottomPadding = 0)
    {
        var scale = Math.Max(1, dpiScale);
        var gap = 12 * scale;
        var margin = 8 * scale;
        var anchoredHeight = Math.Max(0, cardSize.Height - Math.Max(0, bottomPadding));
        var proposed = placement == RingPlacement.Around
            ? new PointD(
                ringCenter.X + ringSize / 2 + gap,
                ringCenter.Y - anchoredHeight / 2)
            : new PointD(
                ringCenter.X - cardSize.Width / 2,
                ringCenter.Y + ringSize / 2 + gap);

        return new PointD(
            Math.Max(
                workArea.Left + margin,
                Math.Min(proposed.X, workArea.Right - cardSize.Width - margin)),
            Math.Max(
                workArea.Top + margin,
                Math.Min(proposed.Y, workArea.Bottom - cardSize.Height - margin)));
    }
}
