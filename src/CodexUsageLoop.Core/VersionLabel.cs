using System.Text.RegularExpressions;

namespace CodexUsageLoop.Core;

public static partial class ReleaseVersionLabel
{
    // Mirrors the macOS AppVersionLabel rules: an exact tag is a release build;
    // anything ahead of a tag, dirty, or not a describe output is a source
    // deployment labeled with the nearest release it is based on.
    public static string Format(string? sourceDescribe, string fallbackVersion)
    {
        if (string.IsNullOrWhiteSpace(sourceDescribe))
        {
            return $"版本 {fallbackVersion}";
        }
        var raw = sourceDescribe.Trim();
        var text = raw;
        var dirty = text.EndsWith("-dirty", StringComparison.Ordinal);
        if (dirty)
        {
            text = text[..^"-dirty".Length];
        }
        var match = DescribeRegex().Match(text);
        if (!match.Success)
        {
            return $"版本 {raw}(源码)";
        }
        if (!int.TryParse(match.Groups[2].Value, out var distance) || distance <= 0)
        {
            return dirty
                ? $"版本 {text}(源码,含未提交修改)"
                : $"版本 {text}";
        }
        var label = $"版本 {text}(源码,领先 {distance} 个提交";
        if (dirty)
        {
            label += ",含未提交修改";
        }
        return label + ")";
    }

    [GeneratedRegex(@"^v(.+?)(?:-(\d+)-g([0-9a-f]+))?$")]
    private static partial Regex DescribeRegex();
}
