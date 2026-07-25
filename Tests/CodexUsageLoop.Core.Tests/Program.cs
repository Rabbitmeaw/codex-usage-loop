using System.Text.Json;
using CodexUsageLoop.Core;

var failures = new List<string>();

void Check(string name, bool condition)
{
    if (!condition)
    {
        failures.Add(name);
    }
}

using (var document = JsonDocument.Parse("""
{
  "primary": {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 2000000000},
  "secondary": {"remainingPercent": "80", "windowDurationMins": 10080}
}
"""))
{
    var snapshot = RateLimitParser.Parse(document.RootElement);
    Check("rate limit snapshot exists", snapshot is not null);
    Check("used percent is inverted", snapshot?.Primary?.RemainingPercent == 75);
    Check("primary label", snapshot?.Primary?.Label == "5 小时");
    Check("secondary label", snapshot?.Secondary?.Label == "7 天");
}

using (var document = JsonDocument.Parse("""{"primary":{"remainingPercent":130}}"""))
{
    Check("percentage clamped", RateLimitParser.Parse(document.RootElement)?.Primary?.RemainingPercent == 100);
}

var pet = new RectD(100, 200, 119, 129);
var diameter = UsageGeometry.BaseRingDiameter(pet, RingPlacement.Around, 1);
Check("accepted around diameter", Math.Abs(diameter - 194.35) < 0.001);
Check("around center", UsageGeometry.RingCenter(pet, diameter, RingPlacement.Around)
    == new PointD(159.5, 264.5));
Check(
    "side placement avoids top task card",
    UsageGeometry.RingCenter(pet, 100, RingPlacement.Right, "top-end").Y == 309.5);
Check("scale clamped", UsageGeometry.ClampAroundScale(2) == 1.5);

var card = UsageGeometry.CardOrigin(
    new PointD(970, 500),
    200,
    RingPlacement.Around,
    new SizeD(190, 70),
    new RectD(0, 0, 1000, 600));
Check("card constrained to work area", card.X == 802 && card.Y == 465);
Check(
    "card size follows 250 percent DPI",
    UsageGeometry.CardSize(hasDualRing: true, dpiScale: 2.5) == new SizeD(475, 185));
var scaledCard = UsageGeometry.CardOrigin(
    new PointD(2_350, 1_300),
    500,
    RingPlacement.Around,
    UsageGeometry.CardSize(hasDualRing: true, dpiScale: 2.5),
    new RectD(0, 0, 2_400, 1_350),
    dpiScale: 2.5,
    bottomPadding: 10);
Check(
    "scaled card uses scaled work-area margin",
    scaledCard == new PointD(1_905, 1_145));
var originalCardOrigin = UsageGeometry.CardOrigin(
    new PointD(1_000, 700),
    500,
    RingPlacement.Around,
    new SizeD(475, 175),
    new RectD(0, 0, 2_400, 1_350),
    dpiScale: 2.5);
var extendedCardOrigin = UsageGeometry.CardOrigin(
    new PointD(1_000, 700),
    500,
    RingPlacement.Around,
    new SizeD(475, 185),
    new RectD(0, 0, 2_400, 1_350),
    dpiScale: 2.5,
    bottomPadding: 10);
Check(
    "extra bottom padding preserves the card top anchor",
    extendedCardOrigin == originalCardOrigin);
Check(
    "card border is 25 percent thicker and follows DPI",
    UsageCardStyle.Metrics(dpiScale: 2.5, windowsBuild: 22_621).BorderWidth == 3.125);
Check(
    "Windows 10 card has square corners",
    UsageCardStyle.Metrics(dpiScale: 1.5, windowsBuild: 19_045).CornerRadius == 0);
Check(
    "Windows 11 card uses an 8-DIP corner radius",
    UsageCardStyle.Metrics(dpiScale: 2.5, windowsBuild: 22_000).CornerRadius == 20);
var cardStyle250 = UsageCardStyle.Metrics(dpiScale: 2.5, windowsBuild: 22_621);
Check(
    "card text uses rounded 15-percent-larger base sizes and follows DPI",
    cardStyle250.PrimaryTextSize == 35
        && cardStyle250.SecondaryTextSize == 27.5);
Check(
    "card text alignment offset follows DPI",
    cardStyle250.PrimaryTextTopOffset == 7.5);
Check(
    "card bottom padding follows DPI",
    cardStyle250.BottomPaddingExtension == 10);
Check(
    "extra card height preserves the status text position",
    UsageCardStyle.StatusTextTop(cardHeight: 185, dpiScale: 2.5) == 127.5);
Check(
    "card secondary text uses a clearer 70-percent white",
    UsageCardStyle.SecondaryTextColor == 0xB3FFFFFF);
Check(
    "card fonts preserve primary and fallback while secondary uses YaHei UI",
    UsageCardStyle.PrimaryFontFamily == "DengXian"
        && UsageCardStyle.SecondaryFontFamily == "Microsoft YaHei UI"
        && UsageCardStyle.FallbackFontFamily == "Segoe UI");
Check(
    "around ring stroke is 85 percent of the current aligned width",
    UsageRingStyle.LineWidth(194.35, compact: false, dpiScale: 1) == 7);
Check(
    "thinner ring stroke follows 250 percent DPI on whole pixels",
    UsageRingStyle.LineWidth(485.875, compact: false, dpiScale: 2.5) == 16);

Check(
    "official releases URI is fixed HTTPS",
    ProjectLinks.ReleasesUri == new Uri(
        "https://github.com/Rabbitmeaw/codex-usage-loop/releases"));

var observedAt = new DateTimeOffset(2026, 7, 25, 14, 30, 0, TimeSpan.Zero);
var statusSnapshot = new UsageSnapshot(
    new UsageWindow("5 小时", 75, null),
    null,
    observedAt,
    "test");
Check(
    "refreshing status takes priority over demo",
    new UsageState
    {
        IsRefreshing = true,
        DemoDualRing = true
    }.StatusText == "正在刷新…");
Check(
    "refresh error preserves existing snapshot message",
    new UsageState
    {
        Snapshot = statusSnapshot,
        ErrorMessage = "请求失败"
    }.StatusText == "刷新失败，仍显示上次数据");
Check(
    "initial refresh error keeps actual message",
    new UsageState
    {
        ErrorMessage = "请求失败"
    }.StatusText == "请求失败");
Check(
    "successful snapshot shows update time",
    new UsageState
    {
        Snapshot = statusSnapshot
    }.StatusText == $"更新于 {observedAt.LocalDateTime:t}");
Check(
    "empty state waits for Codex usage",
    new UsageState().StatusText == "等待 Codex 用量");

if (failures.Count > 0)
{
    Console.Error.WriteLine($"FAILED ({failures.Count}): {string.Join(", ", failures)}");
    return 1;
}

Console.WriteLine("CodexUsageLoop.Core.Tests: 29 checks passed");
return 0;
