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
    UsageGeometry.CardSize(hasDualRing: true, dpiScale: 2.5) == new SizeD(475, 175));
var scaledCard = UsageGeometry.CardOrigin(
    new PointD(2_350, 1_300),
    500,
    RingPlacement.Around,
    UsageGeometry.CardSize(hasDualRing: true, dpiScale: 2.5),
    new RectD(0, 0, 2_400, 1_350),
    dpiScale: 2.5);
Check(
    "scaled card uses scaled work-area margin",
    scaledCard == new PointD(1_905, 1_155));
Check(
    "card border is 25 percent thicker and follows DPI",
    UsageCardStyle.Metrics(dpiScale: 2.5, windowsBuild: 22_621).BorderWidth == 3.125);
Check(
    "Windows 10 card has square corners",
    UsageCardStyle.Metrics(dpiScale: 1.5, windowsBuild: 19_045).CornerRadius == 0);
Check(
    "Windows 11 card uses an 8-DIP corner radius",
    UsageCardStyle.Metrics(dpiScale: 2.5, windowsBuild: 22_000).CornerRadius == 20);

if (failures.Count > 0)
{
    Console.Error.WriteLine($"FAILED ({failures.Count}): {string.Join(", ", failures)}");
    return 1;
}

Console.WriteLine("CodexUsageLoop.Core.Tests: 14 checks passed");
return 0;
