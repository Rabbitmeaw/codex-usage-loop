namespace CodexUsageLoop.Core;

public readonly record struct UsageCardMetrics(double BorderWidth, double CornerRadius);

public static class UsageCardStyle
{
    public const double BaseBorderWidth = 1.25;
    public const double Windows11CornerRadius = 8;
    public const int Windows11MinimumBuild = 22_000;

    public static UsageCardMetrics Metrics(double dpiScale, int windowsBuild)
    {
        var scale = Math.Max(1, dpiScale);
        return new UsageCardMetrics(
            BaseBorderWidth * scale,
            windowsBuild >= Windows11MinimumBuild
                ? Windows11CornerRadius * scale
                : 0);
    }
}
