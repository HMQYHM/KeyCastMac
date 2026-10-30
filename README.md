# 键映 KeyCast (macOS)

一个 macOS 版的按键 / 鼠标 / 手柄显示悬浮窗，用于直播和录屏时实时显示输入操作。配合 OBS「窗口采集」使用。

![license](https://img.shields.io/badge/license-MIT-blue.svg)
![platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey.svg)
![swift](https://img.shields.io/badge/swift-5.9%2B-orange.svg)

## 功能特性

- 多种控件：按键、鼠标、手柄、手柄按键、序列、瀑布流、位移、滚轮、文本输入框。
- 键盘配列预设：104 键 / 108 键 / 98 键 / 数字小键盘 / WASD / MOBA。
- 自定义外观：键帽形状（圆角 / 圆形）、按压特效、键外特效。
- 全屏画布编辑器：1:1 画布，悬浮工具栏和编辑器，可拖动、吸附边缘。
- 手柄三套布局：Xbox / PlayStation / Switch，自动切换 ABXY 面键，支持触控板、Share、Xbox 键等。
- 多手柄支持：可绑定到指定手柄，或识别所有手柄。
- 多语言：简体中文 / 繁體中文 / English / 日本語。
- 多配置文件：保存 / 加载多套配置。
- 置顶显示 / 全屏应用之上显示。

## 系统要求

- macOS 13 或更高版本（Apple Silicon / Intel）。

## 权限

首次使用需要授予两项权限（在「系统设置 → 隐私与安全性」中开启）：

1. 辅助功能（Accessibility）：用于监听鼠标按键。
2. 输入监控（Input Monitoring）：用于监听键盘按键。

## 安装

### 下载 Release

从 Releases 页面下载最新版 DMG，拖入「应用程序」即可。

### 从源码构建

要求：Xcode 或 Swift 5.9+。

    git clone https://github.com/你的用户名/KeyCastMac.git
    cd KeyCastMac
    ./build.sh       # 构建 app
    ./install.sh     # 安装到 /Applications 并启动

打包 DMG：

    ./make-dmg.sh

> 说明：build.sh 会优先使用本机名为 "KeyCast Dev" 的自签名证书做代码签名（用于 TCC 权限持久化）；没有该证书时自动回退到 ad-hoc 签名。

## 使用

1. 运行后，菜单栏会出现键盘图标。
2. 点击图标 → 打开设置。
3. 在画布上添加控件（按键 / 鼠标 / 手柄等），调整位置和外观。
4. 覆盖层会实时显示输入。
5. 在 OBS 中通过「窗口采集」选择「键映 Overlay」即可采集。

## 多语言

在「设置 → 系统 → 语言」中切换：简体中文 / 繁體中文 / English / 日本語。

## 项目结构

    Sources/KeyCast/
      main.swift             # 入口
      AppDelegate.swift      # 应用生命周期 / 菜单栏 / 权限
      OverlayController.swift # 覆盖层窗口与绘制
      SettingsView.swift     # 设置界面
      Models.swift           # 数据模型
      AppState.swift         # 应用状态
      EventMonitor.swift     # 键盘 / 鼠标事件监听
      GamepadMonitor.swift   # 手柄监听
      KeyboardPresets.swift  # 键盘配列预设
      Localization.swift     # 多语言

## 开源协议

MIT License