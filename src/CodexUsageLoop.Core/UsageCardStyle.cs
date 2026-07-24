namespace CodexUsageLoop.Core;

public readonly record struct UsageCardMetrics(
    double BorderWidth,
    double CornerRadius,
    double PrimaryTextSize,
    double SecondaryTextSize,
    double PrimaryTextTopOffset,
    double BottomPaddingExtension);

public static class UsageCardStyle
{
    public const double BaseBorderWidth = 1.25;
    public const double Windows11CornerRadius = 8;
    public const int Windows11MinimumBuild = 22_000;
    public const double PrimaryTextSize = 14;
    public const double SecondaryTextSize = 11;
    public const double PrimaryTextTopOffset = 3;
    public const double BottomPaddingExtension = 4;
    public const double StatusTextBottomInset = 19;
    public const uint SecondaryTextColor = 0xB3FFFFFF;
    public const string PrimaryFontFamily = "DengXian";
    public const string SecondaryFontFamily = "Microsoft YaHei UI";
    public const string FallbackFontFamily = "Segoe UI";

    public static UsageCardMetrics Metrics(double dpiScale, int windowsBuild)
    {
        var scale = Math.Max(1, dpiScale);
        return new UsageCardMetrics(
            BaseBorderWidth * scale,
            windowsBuild >= Windows11MinimumBuild
                ? Windows11CornerRadius * scale
                : 0,
            PrimaryTextSize * scale,
            SecondaryTextSize * scale,
            PrimaryTextTopOffset * scale,
            BottomPaddingExtension * scale);
    }

    public static double StatusTextTop(double cardHeight, double dpiScale)
    {
        var scale = Math.Max(1, dpiScale);
        return cardHeight - (StatusTextBottomInset + BottomPaddingExtension) * scale;
    }
}
