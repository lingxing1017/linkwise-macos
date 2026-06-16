# 拾链 macOS 客户端

拾链 macOS 客户端是 [拾链 Linkwise](https://github.com/lingxing1017/linkwise) 的菜单栏应用，用于连接自托管的拾链服务，在 macOS 菜单栏中快速浏览、打开和保存书签。

服务端负责收藏、整理、导入和导出链接；本客户端负责把拾链带到桌面环境里，让常用链接和“保存当前页面”更顺手。

## 功能

- 在菜单栏按目录浏览拾链书签
- 支持多级目录和未分类书签展示
- 从拾链服务同步书签并缓存到本地
- 支持启动时自动刷新书签
- 支持用系统默认浏览器或指定浏览器打开书签
- 支持复制书签 URL
- 支持保存当前浏览器页面到拾链
- 支持通过 `linkwise://save` 从外部应用唤起保存窗口
- 支持连接测试
- 支持浏览器扫描和自定义浏览器

## 快速开始

客户端需要运行在 macOS 14 或更高版本，并连接到已部署、可访问的拾链服务端。

### 下载应用

从 [GitHub Releases](https://github.com/lingxing1017/linkwise-macos/releases/latest) 下载最新的 `拾链.zip`，解压后会得到：

```text
拾链.app
```

将 `拾链.app` 移动到 `/Applications` 目录后打开使用。

### 配置服务

启动应用后，点击菜单栏中的拾链图标，打开“设置...”，填写拾链服务地址，例如：

```text
http://localhost:7500
```

点击“连接测试”确认服务可用。连接成功后，可以在菜单中刷新书签并开始使用。

### 使用菜单栏

点击菜单栏中的拾链图标，可以按目录浏览已同步的书签。菜单顶部会显示同步状态，点击“上次同步”或“尚未同步”菜单项可以手动刷新书签。

点击书签会使用默认浏览器打开。也可以在书签子菜单中选择其他已安装浏览器打开，或复制该书签的 URL。

在浏览器中打开网页后，点击“保存当前页面”，客户端会尝试读取当前标签页的标题和 URL，并弹出保存窗口。

> [!NOTE]
> 第一次保存当前页面时，macOS 可能会要求授予自动化权限，请在系统设置中允许“拾链”控制对应浏览器。

## 说明

### 浏览器

客户端会自动扫描常见浏览器，包括 Safari、Google Chrome、Microsoft Edge、Firefox、Brave Browser、Arc、Opera、Helium、Vivaldi、Chromium、Tor Browser、Orion、Dia 和 Comet。

在设置中可以选择默认打开浏览器，也可以点击“添加浏览器”手动选择其他支持 `http` 或 `https` 链接的 macOS App。

> [!NOTE]
> 浏览器列表主要用于“打开书签时选择浏览器”。“保存当前页面”依赖浏览器是否支持 AppleScript 读取当前标签页，即使某个浏览器可以用于打开书签，也不一定能被客户端读取当前页面信息。

当前页读取对 Safari、Google Chrome、Microsoft Edge、Brave Browser 和 Helium 有明确适配；其他浏览器会尝试兼容常见的 AppleScript 标签页结构。如果读取失败，客户端会尝试使用剪贴板中的 URL 作为备选。

### URL Scheme

客户端注册了 `linkwise://` URL Scheme，可以从浏览器扩展、自动化脚本或其他应用唤起保存窗口：

```text
linkwise://save?url=https%3A%2F%2Fexample.com&title=Example&folder=Read%20Later
```

参数说明：

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `url` | 是 | 要保存的网页地址，仅支持 `http` 和 `https` |
| `title` | 否 | 书签标题 |
| `folder` | 否 | 保存到拾链中的目录名称 |

`linkwise://` 需要打包后的 `.app` 被 macOS 识别后才会注册。使用 `swift run LinkwiseApp` 开发运行时不会注册该 URL Scheme。

### 本地数据与权限

客户端本身不保存拾链服务端的 WebDAV 密码，也不直接访问服务端数据库。它会在本机保存以下配置和缓存：

- 拾链服务地址
- 启动时是否自动刷新
- 默认打开浏览器
- 自定义浏览器记录
- 已同步书签缓存

配置保存在 macOS `UserDefaults` 中。书签缓存默认保存在：

```text
~/Library/Application Support/Linkwise/cache.json
```

“保存当前页面”需要 macOS 自动化权限，用于读取当前浏览器标签页标题和 URL。

## 开发

从源码构建时需要 Swift 6 工具链和 Xcode Command Line Tools。

### 项目结构

```text
Sources/LinkwiseApp/   macOS 菜单栏应用代码
Sources/LinkwiseCore/  拾链 API、书签模型和本地缓存
Tests/                 单元测试
Resources/             应用图标资源
scripts/               打包脚本
dist/                  本地构建产物，默认不提交
```

### 本地运行

```bash
swift run LinkwiseApp
```

开发运行时不会自动生成完整 `.app` 包，也不会注册 `linkwise://`。如果需要测试 URL Scheme 或完整菜单栏 App 行为，请使用 `scripts/package-app.sh` 打包后运行 `dist/拾链.app`。

### 运行测试

```bash
swift test
```

### 本地打包

```bash
scripts/package-app.sh
```

打包完成后会生成：

```text
dist/拾链.app
```

完整的 `.app` 包会包含应用图标、菜单栏后台运行配置和 `linkwise://` URL Scheme 注册信息。

GitHub Actions 会在打包流程中运行测试、生成 `dist/拾链.app`，再压缩为 `拾链.zip` 并发布到 GitHub Release。Release 标签格式为：

```text
macos-YYYY.MM.DD
```
