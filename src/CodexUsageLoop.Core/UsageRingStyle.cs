namespace CodexUsageLoop.Core;

public static class UsageRingStyle
{
    public const double PreviousStrokeMultiplier = 2;
    public const double StrokeScale = 0.75;
    public const double RefinementScale = 0.85;

    public static double LineWidth(double physicalDiameter, bool compact, double dpiScale)
    {
        var scale = Math.Max(1, dpiScale);
        var logicalDiameter = physicalDiameter / scale;
        var originalWidth = Math.Max(
            2,
            Math.Min(compact ? 6 : 5, logicalDiameter * (compact ? 0.055 : 0.045)));
        var alignedWidth = Math.Max(
            1,
            Math.Round(
                originalWidth * PreviousStrokeMultiplier * StrokeScale * scale,
                MidpointRounding.AwayFromZero));
        return Math.Max(
            1,
            Math.Round(alignedWidth * RefinementScale, MidpointRounding.AwayFromZero));
    }
}
