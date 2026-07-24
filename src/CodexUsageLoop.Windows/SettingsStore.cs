using CodexUsageLoop.Core;
using Microsoft.Win32;

namespace CodexUsageLoop.Windows;

internal sealed class SettingsStore
{
    private const string RegistryPath = @"Software\CodexUsageLoop";
    private readonly bool _isTestInstance = !string.IsNullOrWhiteSpace(
        Environment.GetEnvironmentVariable("CODEX_USAGE_LOOP_TEST_INSTANCE_ID"));

    internal UsageState Load()
    {
        if (_isTestInstance)
        {
            return new UsageState();
        }
        using var key = Registry.CurrentUser.CreateSubKey(RegistryPath);
        return new UsageState
        {
            AlwaysVisible = ReadBool(key, "AlwaysVisible"),
            ManualMove = ReadBool(key, "ManualMoveV2"),
            LaunchWithCodexPet = ReadBool(key, "LaunchWithCodexPetV1"),
            RingPlacement = Enum.TryParse<RingPlacement>(
                key.GetValue("RingPlacementV2") as string,
                true,
                out var placement)
                ? placement
                : RingPlacement.Around,
            AroundRingScale = UsageGeometry.ClampAroundScale(
                ReadDouble(key, "AroundRingScaleV1", 1)),
            OuterRingColor = ReadColor(key, "OuterRingColorV1", RingColor.DefaultOuter),
            InnerRingColor = ReadColor(key, "InnerRingColorV1", RingColor.DefaultInner)
        };
    }

    internal void Save(UsageState state)
    {
        if (_isTestInstance)
        {
            return;
        }
        using var key = Registry.CurrentUser.CreateSubKey(RegistryPath);
        key.SetValue("AlwaysVisible", state.AlwaysVisible ? 1 : 0, RegistryValueKind.DWord);
        key.SetValue("ManualMoveV2", state.ManualMove ? 1 : 0, RegistryValueKind.DWord);
        key.SetValue("LaunchWithCodexPetV1", state.LaunchWithCodexPet ? 1 : 0, RegistryValueKind.DWord);
        key.SetValue("RingPlacementV2", state.RingPlacement.ToString(), RegistryValueKind.String);
        key.SetValue("AroundRingScaleV1", state.AroundRingScale.ToString(
            System.Globalization.CultureInfo.InvariantCulture), RegistryValueKind.String);
        WriteColor(key, "OuterRingColorV1", state.OuterRingColor);
        WriteColor(key, "InnerRingColorV1", state.InnerRingColor);
    }

    internal PointD? LoadManualPosition()
    {
        if (_isTestInstance)
        {
            return null;
        }
        using var key = Registry.CurrentUser.CreateSubKey(RegistryPath);
        if (key.GetValue("ManualX") is int x && key.GetValue("ManualY") is int y)
        {
            return new PointD(x, y);
        }
        return null;
    }

    internal void SaveManualPosition(int x, int y)
    {
        if (_isTestInstance)
        {
            return;
        }
        using var key = Registry.CurrentUser.CreateSubKey(RegistryPath);
        key.SetValue("ManualX", x, RegistryValueKind.DWord);
        key.SetValue("ManualY", y, RegistryValueKind.DWord);
    }

    private static bool ReadBool(RegistryKey key, string name) =>
        key.GetValue(name) is int value && value != 0;

    private static double ReadDouble(RegistryKey key, string name, double fallback)
    {
        return double.TryParse(
            key.GetValue(name) as string,
            System.Globalization.NumberStyles.Float,
            System.Globalization.CultureInfo.InvariantCulture,
            out var value)
            ? value
            : fallback;
    }

    private static RingColor ReadColor(RegistryKey key, string name, RingColor fallback)
    {
        var text = key.GetValue(name) as string;
        var parts = text?.Split(',');
        return parts?.Length == 3
            && byte.TryParse(parts[0], out var red)
            && byte.TryParse(parts[1], out var green)
            && byte.TryParse(parts[2], out var blue)
                ? new RingColor(red, green, blue)
                : fallback;
    }

    private static void WriteColor(RegistryKey key, string name, RingColor color)
    {
        key.SetValue(
            name,
            $"{color.Red},{color.Green},{color.Blue}",
            RegistryValueKind.String);
    }
}
