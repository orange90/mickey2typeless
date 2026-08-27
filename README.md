# MicKey

[![CI](https://github.com/orange90/insta360mic2typelss/actions/workflows/ci.yml/badge.svg)](https://github.com/orange90/insta360mic2typelss/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

简体中文 | [English](README_EN.md)

MicKey 是一个原生 macOS 26 菜单栏应用，把麦克风 USB 接收器的 Consumer HID 按钮映射为 Fn (Globe)、Esc、功能键、字母数字或自定义快捷键。它直接使用 IOKit 与 CoreGraphics，不依赖 Karabiner、Hammerspoon 或虚拟键盘驱动，也不包含任何品牌或型号的内置设备配置。

## 功能

- 首次启动默认使用简体中文，可在“设置 → 通用 → 界面语言”中即时切换中文或 English。
- 学习并确认一个外接 USB Consumer HID 接收器按键，保存完整设备指纹。
- 映射为 Fn (Globe)、常用按键、F1–F20、字母数字或带修饰键的自定义快捷键。
- 支持即时响应，以及保留单击、双击与长按硬件手势的响应模式。
- 原生 Universal 2 应用；不联网、不读取录音、不申请麦克风权限。

## 安装

从 [GitHub Releases](https://github.com/orange90/insta360mic2typelss/releases) 下载最新的已签名、公证 DMG，将 MicKey 拖入“应用程序”文件夹后启动。首次使用需按引导授予“输入监控”和“辅助功能”权限。

## 麦克风兼容性

### HID 是什么

HID 是 Human Interface Device（人机接口设备）的缩写。键盘、鼠标和遥控器上的按键，通常都会通过 HID 向电脑报告“按下”和“松开”。

一些无线麦克风的 USB 接收器实际上是一个复合设备：一部分负责把声音传给 Mac，另一部分把接收器或麦克风上的实体按键作为 Consumer HID 事件发送给 Mac。MicKey 只处理后一部分，把这个按键转换成键盘按键；它不会读取、处理或录制麦克风声音。因此，一支麦克风能够在 Mac 上正常录音，并不代表它的实体按键一定能被 MicKey 使用。

### 设备识别方式

- MicKey 不根据品牌、产品名或预设的 VID/PID 猜测设备。首次使用时，它只寻找外接 USB Consumer HID 候选设备。
- HID 描述符本身不会告诉应用“这是麦克风”。用户需要进入“识别接收器按键”，按一次目标按钮，然后核对产品、厂商、VID/PID、Usage Page 和 Usage 后主动确认。
- 确认后，MicKey 保存完整设备指纹。以后只有相同指纹的接收器和相同 HID Element 才会自动恢复映射，不会把所有音量键或 Consumer HID 设备当成麦克风。

### 支持范围

- **可能支持：** 任意品牌或型号的 USB 麦克风接收器，只要它同时暴露外接 USB Consumer HID 接口，并且目标按键会向 macOS 发送 HID 按下与松开事件。
- **不支持：** 只有音频输入、没有 Consumer HID 按键接口的 USB 麦克风；通过 3.5mm 音频口连接的麦克风；只通过蓝牙连接且没有 USB HID 接收器的麦克风；按键事件由接收器固件自行处理、不会报告给 macOS 的设备。

学习模式不是对所有麦克风的通用适配。MicKey 目前只观察 `Usage Page 0x0C` 的外接 USB Consumer HID 设备，并排除内置设备、键盘、触控板和名称明确的虚拟设备。如果进入学习模式后按键没有出现待确认的设备，通常表示该接收器没有提供 MicKey 能使用的 HID 事件。

目前一次只能保存一个接收器配置。改用另一款接收器时，需要先“忘记设备”，再重新识别。项目不承诺某个具体麦克风型号一定兼容，是否可用取决于接收器实际提供的 HID 描述符和按键事件。

## 安全边界

- 应用不内置任何厂商、产品名、VID/PID 或按键 Usage 配置，也不会自动认领一个从未由用户确认的设备。
- 学习模式只观察外接 USB Consumer HID 设备，并排除内置、键盘、触控板和名称明确的虚拟设备。用户确认产品、厂商、VID/PID 与 Element 前不会独占未知设备。
- 保存的身份由 transport、product、manufacturer、VID、PID、usage page 与 usage 共同组成；序列号不参与身份判断。
- 映射时只以 `kIOHIDOptionsTypeSeizeDevice` 打开已确认的 Consumer HID 接口，音频接口不受影响。暂停、退出、睡眠或 USB 拔出都会释放接口；进程崩溃时 macOS 内核也会关闭独占连接。
- 应用没有 App Sandbox，不请求麦克风权限，不包含网络代码，也不读取音频或录音。仅使用输入监控和辅助功能权限。

## 开发与构建

要求 Xcode 26、macOS 26 SDK 和 XcodeGen：

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MicKey.xcodeproj -scheme MicKey \
  -destination 'platform=macOS' build
```

运行测试：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MicKey.xcodeproj -scheme MicKey \
  -destination 'platform=macOS' test
```

工程将 `ARCHS` 固定为 `arm64 x86_64`，产物为 Universal 2。`project.yml` 是工程配置的源文件；更改它后重新运行 XcodeGen。

## 响应模式

- 即时响应：实体按下时发送 key down，实体松开时发送 key up，保留按住时长。
- 保留硬件手势：按住 180ms 后开始输出；单击在 320ms 判定窗口后输出一次 50ms 按键；双击和三击不输出映射。降噪与静音仍是麦克风固件内部行为，应用不能阻止它们。

## 发布

配置 Developer ID Application 证书、开发者 Team ID 和 `notarytool` 钥匙串 profile 后运行：

```sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID \
NOTARY_PROFILE=YOUR_NOTARY_PROFILE \
./scripts/package_release.sh
```

脚本会 archive、导出签名应用、创建 DMG、提交 Apple 公证并 staple，同时生成 SHA-256 校验文件。产物名称自动使用 `MARKETING_VERSION`，例如 `release/MicKey-1.0.0.dmg`。Hardened Runtime 已启用，App Sandbox 已禁用。完整流程见 [RELEASE.md](RELEASE.md)。

## 真机验收

自动化测试无法替代以下硬件验证：

1. 使用至少三款不同品牌或硬件批次的 USB 麦克风接收器，记录哪些设备暴露了 Consumer HID 接口。
2. 分别完成候选设备检测、按键学习、信息确认、保存与 USB 重连；确认代码没有依赖某个厂商、产品名或固定 VID/PID。
3. 映射后确认没有系统音量 HUD，Mac 自带键盘音量键仍正常。
4. 在 Typeless 中分别验证 Fn 单击、按住和松开，并验证两种响应模式。
5. 验证错误候选取消、权限拒绝、Karabiner 占用提示、重试、睡眠唤醒和 USB 重连。
6. 暂停、正常退出和强制结束进程后，确认接收器的原始按键行为立即恢复。

## 参与贡献

请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。安全问题请按 [SECURITY.md](SECURITY.md) 私下报告。项目采用 [MIT License](LICENSE)。
