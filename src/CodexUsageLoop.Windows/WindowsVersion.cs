using System.Runtime.InteropServices;

namespace CodexUsageLoop.Windows;

internal static class WindowsVersion
{
    internal static int BuildNumber { get; } = ReadBuildNumber();

    private static int ReadBuildNumber()
    {
        var version = new NativeMethods.RTL_OSVERSIONINFOEX
        {
            dwOSVersionInfoSize = (uint)Marshal.SizeOf<NativeMethods.RTL_OSVERSIONINFOEX>()
        };

        return NativeMethods.RtlGetVersion(ref version) == 0
            ? checked((int)version.dwBuildNumber)
            : Environment.OSVersion.Version.Build;
    }
}
