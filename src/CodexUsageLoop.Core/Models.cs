namespace CodexUsageLoop.Core;

public static class ProjectLinks
{
    public static Uri ReleasesUri { get; } = new(
        "https://github.com/Rabbitmeaw/codex-usage-loop/releases");
}

public enum RingPlacement
{
    Around,
    Left,
    Right
}

public readonly record struct RingColor(byte Red, byte Green, byte Blue)
{
    public static RingColor DefaultOuter => new(0, 199, 176);
    public static RingColor DefaultInner => new(0, 122, 255);
}

public sealed record UsageWindow(string Label, double RemainingPercent, DateTimeOffset? ResetsAt)
{
    public bool IsWeekly => Label == "7 天";
}

public sealed record UsageSnapshot(
    UsageWindow? Primary,
    UsageWindow? Secondary,
    DateTimeOffset ObservedAt,
    string Source)
{
    public IReadOnlyList<UsageWindow> Windows =>
        new[] { Primary, Secondary }.OfType<UsageWindow>().ToArray();
}

public sealed class UsageState
{
    public UsageSnapshot? Snapshot { get; set; }
    public string? ErrorMessage { get; set; }
    public bool IsRefreshing { get; set; }
    public bool DemoDualRing { get; set; }
    public bool AlwaysVisible { get; set; }
    public bool ManualMove { get; set; }
    public RingPlacement RingPlacement { get; set; } = RingPlacement.Around;
    public bool LaunchWithCodexPet { get; set; }
    public double AroundRingScale { get; set; } = 1;
    public RingColor OuterRingColor { get; set; } = RingColor.DefaultOuter;
    public RingColor InnerRingColor { get; set; } = RingColor.DefaultInner;

    public bool HasRealDualRing => (Snapshot?.Windows.Count ?? 0) > 1;
    public bool IsDualRingDemoAvailable => !HasRealDualRing;
    public string StatusText
    {
        get
        {
            if (IsRefreshing)
            {
                return "正在刷新…";
            }
            if (DemoDualRing)
            {
                return "双环演示（本地模拟）";
            }
            if (ErrorMessage is not null)
            {
                return Snapshot is not null
                    ? "刷新失败，仍显示上次数据"
                    : ErrorMessage;
            }
            return Snapshot is not null
                ? $"更新于 {Snapshot.ObservedAt.LocalDateTime:t}"
                : "等待 Codex 用量";
        }
    }

    public UsageSnapshot? DisplaySnapshot
    {
        get
        {
            if (!DemoDualRing || !IsDualRingDemoAvailable)
            {
                return Snapshot;
            }

            return new UsageSnapshot(
                new UsageWindow("5 小时", 63, DateTimeOffset.Now.AddHours(2)),
                new UsageWindow("7 天", 84, DateTimeOffset.Now.AddDays(4)),
                DateTimeOffset.Now,
                "demo");
        }
    }
}
