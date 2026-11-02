<div align="center">

<img src="assets/images/icon.png" alt="Vessel" width="88">

# Vessel（器）

自研代理客户端，只做 **Android** 与 **Windows**。

A self-built proxy client for **Android** and **Windows** only.

[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/original0211/Vessel?style=flat-square)](https://github.com/original0211/Vessel/releases/latest)

</div>

## 状态

最新正式版 **v0.2.48**，见 [Releases](https://github.com/original0211/Vessel/releases)；应用内可检查更新，更新源即本仓 Releases。项目持续迭代中。

## 特性

- **双核同装**：mihomo（Clash.Meta）全保真直通；sing-box 为契约子集（见「已知取舍」）。两核同在一个安装内，设置中一键切换。
- **sing-box 契约**：原生 sing-box JSON 原样直用；Clash 配置只做节点层转换并套用一套内置分流模板，承接主流协议节点与选择 / 测速组，包括渲染器自生成的双层测速组与一层用户嵌套组。
- **降级必点名**：sing-box 无法表达的项（不支持的协议与组型、嵌套超过一层的组、引用成环等）在导入与切换时逐项列入降级清单，不静默丢弃；引用完整性全量校验，悬空引用当场报错。订阅屏有降级计数与清单入口。
- **万能导入**：Clash、sing-box 配置、订阅与分享链接一次导入——先解析为统一中间表示，再渲染到所选内核。添加配置有四种入口：订阅链接、本地文件、二维码扫描、万能导入；另支持深度链接 `clash://`、`clashmeta://`。
- **订阅管理**：列表显示用量、到期与最后更新时间；支持自动更新与一键全量更新。
- **节点选择**：分组默认折叠、只展开当前出口所在组，折叠组头显示成员数、组内最低延迟与当前选定节点；顶部分组导航条与一行搜索直达任意组，搜索跨组过滤；组内当前出口置顶；一键测试全部延迟。
- **接管方式**：Windows 提供系统代理与 TUN 模式；Android 以 VPN 服务运行。
- **按需连接**（Android）：按 Wi-Fi SSID 等条件自动连接。
- **访问控制**（Android）：按应用决定是否经代理（允许 / 排除名单）。
- **平台细节**：Android 快捷设置磁贴；Windows 系统托盘与全局快捷键。
- **备份与重置**：本地备份与恢复；一键重置把全部设置恢复为经调校的默认，订阅、配置与测速历史不受影响，确认后连接断开并以新配置重连。
- **设置搜索**：设置项可搜索直达。
- **界面与品牌**：原研哉「白 · Emptiness」设计语言——白之容器、发丝线、圆角与投影为零，朱红只标记「当前」；场色浅 / 深 / 纯黑三档并可跟随系统，液态玻璃仅「无 / 标准」两档；品牌标记「一点」：细环与环上 157° 处一粒朱红点。

## 已知取舍

- sing-box 只做契约子集：订阅自带的分流规则脑（规则集展开、链式代理、冷门协议等）不移植，无法表达的进降级清单逐项点名。
- per-profile 渲染（按单个订阅定制渲染参数）尚未实现。
- 不提供连接、请求与 DNS 的在线监视视图——减法取舍；运行日志保留。

## 下载

到 [Releases](https://github.com/original0211/Vessel/releases/latest) 下载最新版：

| 平台 | 文件 |
| --- | --- |
| Android arm64-v8a | `Vessel-<版本>-android-arm64-v8a.apk` |
| Android armeabi-v7a | `Vessel-<版本>-android-armeabi-v7a.apk` |
| Android x86_64 | `Vessel-<版本>-android-x86_64.apk` |
| Windows amd64 | `Vessel-<版本>-windows-amd64-setup.exe`（安装版）/ `Vessel-<版本>-windows-amd64.zip`（便携版） |
| Windows arm64 | `Vessel-<版本>-windows-arm64-setup.exe` / `Vessel-<版本>-windows-arm64.zip` |

每版附 `SHA256SUMS` 供校验。Android 应用 ID 为 `com.kfusion.app`。

## 从源码构建

发布构建使用 Flutter **3.47.6**（CI 钉版）、Go **1.27.1** 与 Rust（rustup）；Android 构建另需 JDK 17，Windows 构建在 Windows 宿主上进行。

```bash
git clone --recursive https://github.com/original0211/Vessel.git
cd Vessel
flutter pub get
dart setup.dart android   # 或 windows
```

流水线定义见 [.github/workflows/build.yaml](.github/workflows/build.yaml)。

## 许可与致谢

Vessel 以 [GPL-3.0](LICENSE) 发布。代理内核为 [mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo) 与 [sing-box](https://github.com/SagerNet/sing-box)。完整归属见 [NOTICE.md](NOTICE.md)。

---

## English

**Vessel** is a self-built proxy client for **Android** and **Windows** only.

### Status

Latest stable release: **v0.2.48**, see [Releases](https://github.com/original0211/Vessel/releases). The app checks for updates against this repository's Releases. Development is ongoing.

### Features

- **Two cores in one install**: mihomo (Clash.Meta) passes configurations through with full fidelity; sing-box is a contract subset (see "Known trade-offs"). Switch cores in Settings.
- **The sing-box contract**: native sing-box JSON is used as-is; Clash configurations get a node-layer conversion plus one built-in routing template, covering mainstream protocol nodes and selector / url-test groups, including renderer-generated two-level url-test groups and one level of user-nested groups.
- **Degradation is always named**: anything sing-box cannot express (unsupported protocols or group types, groups nested deeper than one level, reference cycles, …) is listed item by item in a degradation list at import and switch time — never silently dropped. Referential integrity is fully checked; dangling references fail on the spot. The subscriptions screen shows a degradation count with an entry to the list.
- **Universal import**: Clash and sing-box configurations, subscriptions and share links are imported in one go — parsed into a unified intermediate representation first, then rendered to the selected core. Profiles can be added four ways: subscription link, local file, QR code scan, and universal import; deep links `clash://` and `clashmeta://` are also supported.
- **Subscription management**: the list shows usage, expiry and last-update time; automatic updates and one-tap update-all are supported.
- **Node picking**: groups are folded by default — only the group holding the current exit is expanded; a folded group header shows its member count, its lowest in-group latency and its currently selected node. A group chip bar and a one-line search reach any group, with cross-group filtering while searching; the current exit is pinned to the top of its group; one tap tests all latencies.
- **Traffic takeover**: system proxy and TUN mode on Windows; a VPN service on Android.
- **On-demand connection** (Android): connect automatically based on conditions such as the Wi-Fi SSID.
- **Access control** (Android): decide per app whether it goes through the proxy (allow / exclude lists).
- **Platform touches**: a Quick Settings tile on Android; system tray and global hotkeys on Windows.
- **Backup and reset**: local backup and restore; a one-tap reset returns all settings to the tuned defaults — subscriptions, profiles and latency history are unaffected — and, once confirmed, the connection drops and reconnects with the new configuration.
- **Settings search**: every settings item is searchable.
- **Interface and brand**: Kenya Hara's "White · Emptiness" design language — a white container, hairlines, zero corner radius and zero shadow, with vermilion marking only "current". Field colors come in light / dark / pure black and can follow the system; liquid glass is limited to off / standard. The brand mark is "one point": a thin ring with a single vermilion dot at 157°.

### Known trade-offs

- sing-box is a contract subset: the routing brain shipped inside subscriptions (rule-set expansion, chained proxies, niche protocols, …) is not ported; whatever cannot be expressed is named in the degradation list.
- Per-profile rendering (custom rendering parameters per subscription) is not implemented yet.
- No live monitoring views for connections, requests or DNS — a deliberate subtraction; runtime logs are kept.

### Download

Get the latest build from [Releases](https://github.com/original0211/Vessel/releases/latest):

| Platform | Files |
| --- | --- |
| Android arm64-v8a | `Vessel-<version>-android-arm64-v8a.apk` |
| Android armeabi-v7a | `Vessel-<version>-android-armeabi-v7a.apk` |
| Android x86_64 | `Vessel-<version>-android-x86_64.apk` |
| Windows amd64 | `Vessel-<version>-windows-amd64-setup.exe` (installer) / `Vessel-<version>-windows-amd64.zip` (portable) |
| Windows arm64 | `Vessel-<version>-windows-arm64-setup.exe` / `Vessel-<version>-windows-arm64.zip` |

Each release ships a `SHA256SUMS` file for verification. The Android application id is `com.kfusion.app`.

### Build from source

Release builds use Flutter **3.47.6** (the CI pin), Go **1.27.1** and Rust (via rustup); Android builds also need JDK 17, and Windows builds run on a Windows host.

```bash
git clone --recursive https://github.com/original0211/Vessel.git
cd Vessel
flutter pub get
dart setup.dart android   # or windows
```

See [.github/workflows/build.yaml](.github/workflows/build.yaml) for the pipeline definition.

### License and acknowledgements

Vessel is released under [GPL-3.0](LICENSE). The proxy cores are [mihomo / Clash.Meta](https://github.com/MetaCubeX/mihomo) and [sing-box](https://github.com/SagerNet/sing-box). Full attribution lives in [NOTICE.md](NOTICE.md).
