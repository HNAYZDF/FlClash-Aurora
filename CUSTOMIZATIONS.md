# 本仓库的改动说明

这是 [chen08209/FlClash](https://github.com/chen08209/FlClash) 的个人定制构建，
在上游基础上做了界面美化与若干体验调整。

> **This is a personal customised build of FlClash.**
> Upstream: <https://github.com/chen08209/FlClash> — base commit `4b59eca8`.
> Licensed under **GPL-3.0**, the same licence as upstream. All original work
> belongs to the FlClash authors; see [LICENSE](LICENSE).

---

## 界面美化

| 改动 | 说明 |
| --- | --- |
| 极光背景 | 整窗铺一层缓慢漂移的渐变光晕，颜色由当前皮肤的强调色推导，并按配色鲜艳度自动调节强度 |
| 磨砂玻璃窗口 | 使用 Windows 原生 acrylic，窗口半透明并模糊后方桌面 |
| 窗口透明度 | 设置页与仪表盘各有一个滑块，**1–100%** 可调。100% 时底色、面纱、光晕全部归零，只剩控件画在磨砂桌面上 |
| 皮肤 | 8 套中文皮肤：极光、深海、霓虹、翡翠、熔金、虹彩、极夜、石墨。皮肤只存"强调色 + 配色变体 + 纯黑"三项，因此不需要新的持久化字段，也能随配置一起备份恢复 |
| 玻璃卡片 | 卡片改为半透明填充 + 高光斜切，悬停时轻微上浮 |
| 霓虹图表 | 折线图与环形图加发光描边、三段渐变填充、端点光点 |
| 侧边栏 | 选中项改为渐变胶囊 + 光晕 + 强调色图标 |
| 开始按钮 | 呼吸填充 + 向外扩散的雷达波纹 |
| 应用图标 | 重绘的方圆形图标与四种状态托盘图标 |

## 功能调整

- **关闭上游自动更新**：本构建报告的是上游版本号，更新器会提示安装官方版，
  而安装官方版会覆盖上述全部定制。因此 `lib/common/request.dart` 的更新检查
  在本构建中直接返回，设置页也不再提供手动检查入口。
- 关于页新增「界面美化」署名区块，链接到 B 站 **hnayzdf**。
- 新增文案已补齐 4 种语言（en / ja / ru / zh_CN），各 785 个键完全一致。

## 与上游的关系

- 基线上游提交：`4b59eca8`
- 子模块 `core/Clash.Meta`：`8597778c`（v0.6.0-4281）
- 本仓库**只保留定制改动**，其余与上游一致；需要跟进上游时可正常 `git merge`

## 构建

```bash
git clone --recursive <this-repo>
flutter pub get
dart run build_runner build          # 若改动了 freezed / riverpod 模型
flutter build windows --release --dart-define-from-file=env.json
```

`env.json` 由 `setup.dart` 生成，其中包含一个必要的编译开关：

```json
{ "APP_ENV": "stable", "FEATURE_SIDEBAR_BLUR": "true" }
```

**`FEATURE_SIDEBAR_BLUR` 必须为 `true`**，否则窗口不会应用磨砂特效，
透明度滑块会失效并被禁用。用 `dart setup.dart windows --env stable` 打包时会自动带上。

## 体积与性能

实测数据（Windows x64，release 构建）：

| 项目 | 上游原样 | 本仓库 | 变化 |
| --- | --- | --- | --- |
| 安装后占用 | 157.2 MB | **137.6 MB** | −19.6 MB（−12.5%） |
| 安装包 | 42.69 MB | **40.43 MB** | −2.26 MB（−5.3%） |
| 便携 zip | 67.80 MB | **62.59 MB** | −5.21 MB（−7.7%） |
| 空闲 CPU | — | 单核 **1.4%** | 60 秒采样 0.83 秒 |
| 空闲内存 | — | UI ~135 MB + 内核 ~59 MB | — |

做了两件事：

**不再打包 `GEOIP.dat`（19.6 MB）** —— 那是只在 `geodata-mode: true` 时才会被
读取的旧版 trie；默认的 `memconservative` 加载器读的是 `GEOIP.metadb`。
`pubspec.yaml` 因此改为逐个列出地理文件，并同步修改了
`lib/core/controller.dart` 的 `geoFileNameList` —— **这两处必须一起改**，
否则 `initGeo()` 会因 `rootBundle.load` 找不到资源而抛异常，导致内核初始化失败。

> 需要旧版 `.dat` 时：在应用内「工具 → Geo 资源 → 更新」即可下载到数据目录，
> 或者把 `assets/data/GEOIP.dat` 加回 `pubspec.yaml` 与 `geoFileNameList`。

**安装包压缩升到 `lzma2/ultra64`** —— Inno Setup 的最强档，无损。

### 已经到极限的部分

- **Go 内核 69.3 MB**（占安装体积 50%）：`build_config.yaml` 里已经是
  `go_ldflags: "-w -s"`，PE 里没有 `.debug_*` 节、`.symtab` 只有 512 字节 ——
  **没有可剥离的调试信息**。剩下的唯一减法是去掉 `with_gvisor` 标签，
  但那会砍掉 TUN 的 gvisor 栈，属于功能取舍而非优化，故未采用。
- **`flutter_windows.dll` 20.3 MB**：Flutter 引擎，固定成本。
- **`app.so` 15.1 MB**：Dart AOT 快照。
- **地理数据 24.3 MB**：`GEOIP.metadb` / `ASN.mmdb` / `GEOSITE.dat`，运行时必需。

## 已知限制

- Win11 上 acrylic 在拖动/缩放窗口时可能有轻微延迟，这是 DWM 对旧版
  `SetWindowCompositionAttribute` 的固有行为。
- 设置里的「侧边栏背景模糊」实际控制整个窗口的磨砂特效开关；关掉它窗口会变回
  不透明，透明度滑块随之禁用。
- 本仓库的构建**不含 `GEOIP.dat`**。若把 `geodata-mode` 改成 `true`，
  `GEOIP` 规则会失效，需先在应用内更新 Geo 资源。
- 上游测试中有 6 项在改动前就失败（集中在 `core/event.dart`、`l10n_labels.dart`
  等本仓库未修改的文件），与本定制无关。

---

美化：哔哩哔哩 [hnayzdf](https://space.bilibili.com/431149392)
