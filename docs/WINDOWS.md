# CodexUsageLoop for Windows

Windows 版本保留现有 macOS 应用，使用独立的 .NET 项目和原生 Win32 API。
它不使用 WinUI、WPF、WinForms、Electron、Qt 或第三方 GUI/JSON 库。

## 支持范围

- Windows 10 22H2（19045）或 Windows 11；
- x64；
- Per-Monitor V2 DPI awareness；
- 100%、125%、150%、175%、200% 及更高缩放；
- 单显示器和多显示器；
- framework-dependent x64 发布。

暂不提供 ARM64、x86 或自包含 .NET 发布。

## 目录与模块

```text
src/CodexUsageLoop.Core/
  Models.cs                 平台无关的额度、偏好与颜色模型
  Geometry.cs               pet、圆环和卡片的纯几何规则
  UsageCardStyle.cs          卡片描边与系统版本圆角度量
  RateLimitParser.cs        app-server 限额映射

src/CodexUsageLoop.Windows/
  Program.cs                单实例和 Win32 消息循环入口
  AppController.cs          唯一装配/生命周期入口
  NativeMethods.cs          User32/GDI/GDI+/Shell/Comdlg32 P/Invoke 边界
  LayeredRenderer.cs        预乘 Alpha DIB 与分层窗口渲染
  PetLocator.cs             Codex pet 状态、监视器和窗口降级定位
  CodexAppServerClient.cs   app-server stdio JSON-RPC 客户端
  SettingsStore.cs          HKCU 用户偏好
  WindowsVersion.cs         通过 RtlGetVersion 读取真实 Windows 构建号
  Diagnostics.cs            显式启用的本地诊断
  app.manifest              Per-Monitor V2 与 Windows 10 兼容声明

Tests/CodexUsageLoop.Core.Tests/
  Program.cs                无第三方测试框架的核心回归检查

Tests/CodexUsageLoop.FakeCodex/
  Program.cs                app-server 与 Win32 生命周期集成测试替身
```

SwiftPM、`Sources/CodexPetUsageMac`、`Tests/CodexPetUsageMacTests` 和现有
macOS 打包脚本保持独立，不依赖 .NET 项目。

## 运行机制

1. `Program` 在创建任何 HWND 前设置 Per-Monitor V2 DPI awareness，并通过
   当前用户命名互斥体保证单实例。
2. `AppController` 创建一个隐藏消息窗口、一个圆环分层窗口和一个卡片分层
   窗口，再注册通知区域图标。
3. 圆环和卡片使用 `WS_POPUP`、`WS_EX_TOOLWINDOW`、
   `WS_EX_NOACTIVATE`、`WS_EX_TOPMOST` 与 `WS_EX_LAYERED`。因此不进入
   任务栏或 Alt+Tab，不抢前台焦点。
4. `LayeredRenderer` 用系统 GDI+ 抗锯齿绘制到 32-bit top-down、
   premultiplied-ARGB DIB，再由 `UpdateLayeredWindow` 逐像素合成。未使用
   颜色键。
5. 默认圆环带 `WS_EX_TRANSPARENT`，并在 `WM_NCHITTEST` 返回
   `HTTRANSPARENT`。开启“自由拖动位置”后去掉穿透样式，返回
   `HTCAPTION`，由系统完成拖动；位置保存在当前用户注册表。
6. 每秒读取一次 pet 布局和鼠标位置。只有几何、额度、颜色或动画帧变化时
   才重新提交圆环位图；额度变化时临时使用 16 ms 定时器平滑过渡，稳定后
   立即停表。用量每 30 秒主动刷新，并同时接受 app-server 推送。
7. 用量卡片以 96 DPI 下的 190×54/70 DIP 为基准，窗口尺寸、字体、圆点、
   圆角、描边、内边距和屏幕安全边距均按圆环所在显示器的有效 DPI 等比
   缩放；跨屏后下一次布局立即使用目标显示器缩放。卡片使用不透明
   `#202020` WinUI 深色表面、1.25 DIP 描边和 DengXian 字体（不可用时
   回落 Segoe UI）；Windows 10 为直角，Windows 11 按原生 overlay 规范
   使用 8 DIP 圆角。
8. 退出通过 `WM_CLOSE` 进入标准消息循环收尾，停止计时器和 app-server，
   移除通知区域图标，销毁 HWND/HICON/HBITMAP/HDC/GDI+ 对象。

## pet 定位与 DPI

Windows Codex GUI 把 pet 布局写入
`%USERPROFILE%\.codex\.codex-global-state.json` 的
`electron-avatar-overlay-bounds` 和 `electron-avatar-overlay-open`。
Windows 版本只解析这两个 GUI 状态键，不读取认证文件。

Electron 状态使用显示器逻辑坐标；Win32 叠加层在 Per-Monitor V2 模式下使用
物理像素。定位器会：

1. 枚举监视器的物理边界和工作区；
2. 以逻辑显示边界、原点、宽高比和缩放一致性选择监视器；
3. 分别计算 X/Y 缩放并映射 pet 的位置和尺寸；
4. 状态暂时不可读时，退回到 Codex/ChatGPT 的可见小窗口和既有比例估算；
5. Codex 重建窗口造成瞬时缺失时保留上一次可信位置。

Windows 不需要 macOS 的屏幕录制权限。当前版本不捕获 Codex 窗口像素：
新版 Codex 已直接持久化 pet 锚点，窗口状态可满足正常定位，而且避免引入
Windows Graphics Capture 的授权和额外 GPU 成本。若以后 Codex 移除该状态，
可在 `PetLocator` 后增加只在内存中工作的 Windows Graphics Capture /
Direct3D 检测器。

## 构建工具

必需：

- Visual Studio 2026 / Build Tools 2026 可选，不是命令行构建的硬依赖；
- .NET SDK 10.0.300 或更高的 10.0 SDK；
- Windows 10 SDK 10.0.19041 或更高（由 .NET SDK 的 Windows targeting
  pack 提供；若使用 Visual Studio，请选择对应 Windows SDK）。

Debug：

```powershell
dotnet build src/CodexUsageLoop.Windows/CodexUsageLoop.Windows.csproj -c Debug
dotnet run --project src/CodexUsageLoop.Windows/CodexUsageLoop.Windows.csproj -c Debug
```

Release 编译、测试和单文件发布：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts/build-windows.ps1 -Configuration Release -Publish
```

完整 app-server / 分层 UI / 正常退出集成检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts/test-windows-integration.ps1
```

该检查实际验证双窗口额度、当前显示器 DPI 下的卡片物理尺寸、
`WS_EX_LAYERED/TOOLWINDOW/TOPMOST/NOACTIVATE`、任务栏/Alt+Tab 排除、
点击穿透与 `HTCAPTION` 拖动切换，以及 `WM_CLOSE` 资源清理。测试实例使用
独立互斥体、窗口类和内存偏好，不影响正在运行的正常实例或用户注册表。

输出：

```text
dist/windows/win-x64/CodexUsageLoop.Windows.exe
```

打包：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File scripts/package-windows.ps1 -Version 0.2.0
```

生成 x64 ZIP 和相邻的 SHA-256 文件。

## 运行时与 app-server

程序本身需要 Microsoft .NET Runtime 10 x64。用户可以通过微软官方安装器或：

```powershell
winget install Microsoft.DotNet.Runtime.10
```

用量读取还需要可由普通桌面进程执行的官方 Codex CLI。程序按以下顺序寻找：

1. `CODEX_EXECUTABLE` 指定的 `codex.exe`；
2. npm 官方 Codex CLI 的标准 x64 vendor 路径；
3. 常见本机安装路径和 `PATH`；
4. 非 `WindowsApps` 的正在运行的 Codex 安装。

Windows 商店版 Codex GUI 当前把约 350 MB 的内置 `codex.exe` 放在受保护的
`WindowsApps` 包目录，包清单没有声明命令行执行别名。普通桌面进程不能直接
启动该文件。CodexUsageLoop 不复制这个二进制、不修改 ACL、不复用 GUI
私有管道，也不读取认证文件。只有商店 GUI、没有独立 CLI 时，pet 圆环和全部
本地交互仍可用，卡片会显示明确的 CLI 要求，但实时额度暂不可用。

可选诊断（默认不写文件）：

```powershell
$env:CODEX_USAGE_LOOP_DIAGNOSTICS = "$PWD\windows-runtime.log"
.\dist\windows\win-x64\CodexUsageLoop.Windows.exe
```

日志只包含窗口/几何/生命周期摘要和错误，不包含 app-server 原始响应或认证
数据。

## 发布文件与 DLL

framework-dependent 单文件发布目录中只有：

```text
CodexUsageLoop.Windows.exe
```

随程序分发的 DLL：无。

进程运行时使用 Windows 系统 DLL：

- `user32.dll`
- `gdi32.dll`
- `gdiplus.dll`
- `shell32.dll`
- `comdlg32.dll`
- `kernel32.dll`

以及机器上共享安装的 Microsoft .NET Runtime 10。未静态打包 .NET Runtime，
也没有第三方原生或托管 DLL。

## 已知限制

- Windows 商店版 Codex 的内置 CLI 没有外部执行入口；实时额度需要独立官方
  Codex CLI 或 `CODEX_EXECUTABLE`。
- 当前 pet 精确位置来自 Codex GUI 的持久化布局，不做逐像素窗口捕获。
- 当前只发布 x64 framework-dependent 构建。
- Windows 版本的围绕尺寸菜单使用 75%、100%、125%、150% 四个原生菜单
  预设；macOS 版本仍保留连续滑块。
