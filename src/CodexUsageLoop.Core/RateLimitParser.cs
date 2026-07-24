using System.Globalization;
using System.Text.Json;

namespace CodexUsageLoop.Core;

public static class RateLimitParser
{
    public static UsageSnapshot? Parse(JsonElement limits, DateTimeOffset? observedAt = null)
    {
        if (limits.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var primary = TryGetProperty(limits, "primary", out var primaryValue)
            ? ParseWindow(primaryValue)
            : null;
        var secondary = TryGetProperty(limits, "secondary", out var secondaryValue)
            ? ParseWindow(secondaryValue)
            : null;

        return primary is null && secondary is null
            ? null
            : new UsageSnapshot(
                primary,
                secondary,
                observedAt ?? DateTimeOffset.Now,
                "codex app-server");
    }

    private static UsageWindow? ParseWindow(JsonElement value)
    {
        if (value.ValueKind != JsonValueKind.Object)
        {
            return null;
        }

        var remaining = ReadNumber(value, "remainingPercent");
        var used = ReadNumber(value, "usedPercent");
        var percent = remaining ?? (used is null ? null : 100 - used);
        if (percent is null)
        {
            return null;
        }

        var duration = ReadNumber(value, "windowDurationMins");
        var label = duration switch
        {
            >= 10_000 => "7 天",
            <= 720 => "5 小时",
            _ => "当前窗口"
        };

        var resetSeconds = ReadNumber(value, "resetsAt");
        DateTimeOffset? reset = resetSeconds is null
            ? null
            : DateTimeOffset.FromUnixTimeSeconds((long)resetSeconds.Value);

        return new UsageWindow(label, Math.Clamp(percent.Value, 0, 100), reset);
    }

    private static double? ReadNumber(JsonElement value, string name)
    {
        if (!TryGetProperty(value, name, out var property))
        {
            return null;
        }

        if (property.ValueKind == JsonValueKind.Number && property.TryGetDouble(out var number))
        {
            return number;
        }

        if (property.ValueKind == JsonValueKind.String
            && double.TryParse(property.GetString(), NumberStyles.Float, CultureInfo.InvariantCulture, out number))
        {
            return number;
        }

        return null;
    }

    private static bool TryGetProperty(JsonElement value, string name, out JsonElement property)
    {
        return value.TryGetProperty(name, out property);
    }
}
