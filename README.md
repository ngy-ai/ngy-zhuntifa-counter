# 准提法计数器

一个帮助持诵准提咒的 Flutter 应用：每念一遍，点一次按钮记数，也可以开启语音自动计数；首页汇总功课统计。

支持 Android 与 iOS。

## 功能

### 功课页面

- **计数按钮**：点击一次记一遍，同时给出轻微震动与提示音反馈。
- **念珠表盘**：按钮外圈是一串念珠（默认 108 颗），实时显示本串进度；每圆满一串会有提示。
- **实时数据**：顶部显示今日持咒遍数、今日圆满串数、连续持咒天数。
- **语音自动计数**：打开「语音计数」后持续聆听，念满一遍准提咒自动记一遍。按拼音相似度比对——识别成同音字（「飒哆喃」听成「萨多南」）、个别字听错都能正确记数；只有念到结尾「准提娑婆诃」才算圆满，念到一半停下不会被误记。聆听时会回显最近识别到的内容；退到后台自动停止，不会一直占用麦克风。
- **撤销一次**：误触时可回退。
- **结束本次**：把当前这次功课归档为一条记录，计数归零。

### 首页

- **今日功课卡**：今日遍数、每日目标完成度环形进度、一键进入功课页面。
- **累计统计**：累计持咒遍数、连续持咒天数、累计功课天数、单日最高。
- **近七日柱状图**：直观看到近日用功情况。
- **最近功课**：最近 5 次功课的日期、时长与遍数。

### 明细页面

![功课明细](docs/screens/history-light.png)

- **汇总**：本月合计遍数、本月用功天数、累计功课次数，以及累计遍数与有记录天数。
- **按天分组的记录**：日期倒序排列，每天一组，组内显示每次功课的时间段（`04:20 - 04:32`）、持续时长与遍数，组头是当天合计遍数。
- **今日 / 昨天 / 前天**有标记；正在进行中的那次功课会带上「进行中」标签。
- **点击任意一条记录**，可以看到这一次功课里**每一遍的具体时间点**。
- **删除单条记录**：向左滑动某条记录，或点开后在面板底部删除，确认后从统计中扣除；进行中的那一次可以在详情面板里「放弃本次功课」。首页「最近功课」右上角的「全部明细」可直接进入本页。

### 逐次持咒时间

![逐次持咒时间](docs/screens/recitation-light.png)

点开明细里的某一条记录，会展开这一次功课的完整时间线：

- **顶部**：本次功课的日期、时间段与持续时长。
- **汇总**：总遍数、持续时长、平均间隔。
- **逐次时间**：从「第 1 遍」到最后一遍，逐条列出精确到秒的时间点，并标注与上一遍的间隔（`+3 秒`），方便回看当时的用功节奏。
- 每一遍的时间点在计数时就写进存档；升级前保存的记录没有这些数据，会明确提示「这条记录只有总遍数」，不会伪装成有时间点。
- 面板底部可以直接删除这条记录（进行中的那一次则是「放弃本次功课」）。

### 设置（右上角图标）

- 每日目标：21 / 54 / 108 / 216 / 432 / 1080 遍。
- 每串念珠颗数：18 / 21 / 27 / 54 / 108。
- 震动反馈、点击提示音开关。
- 界面皮肤：跟随系统 / 浅色 / 深色。
- 备份与恢复：
  - **导出明细记录**：把全部记录（含进行中的一次）复制成一段文本，可粘贴到备忘录、聊天窗口或文件中保存。
  - **导入恢复**：把这段文本粘贴回来，实时预览将导入的条数与遍数，可选「合并」（按 id 去重追加）或「覆盖」（替换本地记录，有二次确认）。
- 清空全部记录。

## 两套皮肤

| | 浅色 · 宣纸檀金 | 深色 · 墨夜鎏金 |
| --- | --- | --- |
| 首页 | ![浅色首页](docs/screens/home-light.png) | ![深色首页](docs/screens/home-dark.png) |
| 功课 | ![浅色功课](docs/screens/practice-light.png) | ![深色功课](docs/screens/practice-dark.png) |

- 皮肤参数集中在 `lib/theme/app_skin.dart`，以 `ThemeExtension` 注入主题；页面统一通过 `AppSkin.of(context)` 取色，不再散落硬编码色值。
- 两套皮肤各自独立设计——渐变、念珠三态、投影都分别定过，不是同一套配色的明暗反转：
  - **浅色**：暖白宣纸底 + 檀褐主色，计数按钮是藏红实心渐变配白字。
  - **深色**：墨底暖光 + 鎏金主色，计数按钮是明亮黄铜配深墨字。
- 设置面板可切换皮肤，选择随功课数据一起持久化；切换即时生效且不影响正在进行中的计数。
- `test/app_skin_test.dart` 会校验两套皮肤的可读性对比度（正文、按钮、念珠、图表高亮），避免改配色后文字看不清。

## 运行

```bash
flutter pub get
flutter run                 # 连接设备或模拟器后运行
flutter test                # 运行单元测试与组件测试
flutter analyze             # 静态检查
```

### 在 Android 上运行（Windows）

Gradle 需要 **JDK 17+**；本机 `JAVA_HOME` 默认指向 Java 8，直接构建会在起步阶段失败（`Dependency requires at least JVM runtime version 11`）。把 Flutter 用的 JDK 指到本机的 JDK 17（只需设置一次）：

```powershell
flutter config --jdk-dir="E:\dev\ms-17.0.18"
```

也可以只在当前会话里临时覆盖：

```powershell
$env:JAVA_HOME = 'E:\dev\ms-17.0.18'
```

> JDK 必须是**完整版**（带 `jlink.exe`）。IDEA 自带的 `jbr` 等裁剪版会报 `jlink executable ... does not exist`；Java 26 则超出 Gradle 8.14 的支持范围。

启动模拟器并运行：

```powershell
flutter emulators --launch pixel36   # 本机模拟器 id，已在运行可跳过
flutter devices                      # 确认设备已连接，如 emulator-5554
flutter run -d emulator-5554         # 运行，支持热重载
```

不用 `flutter run`、直接把 debug 包装到模拟器：

```powershell
flutter build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s emulator-5554 shell am start -n com.ngy.ngy_zhuntifa_counter/.MainActivity
```

打包：

```bash
flutter build apk --release          # Android
flutter build appbundle --release    # Android（上架 Google Play）
flutter build ios --release          # iOS，需要在 macOS 上执行
```

> iOS 首次构建时 Flutter 会自动生成 `ios/Podfile` 并执行 `pod install`。

### 发布构建包（GitHub Releases）

仓库自带 GitHub Actions 工作流（`.github/workflows/release.yml`）：

- **打标签自动发版**：推送 `v*` 标签会触发构建，完成后在仓库的 Releases 页面生成一条带 APK 的发行版，手机直接下载安装：

  ```bash
  git tag v1.0.0          # 版本号与 pubspec.yaml 保持一致
  git push origin v1.0.0
  ```

- **手动触发**：在仓库的 **Actions → Release APK → Run workflow** 手动运行；手动触发不会创建 Release，产物在本次运行的 Artifacts 里下载。
- 构建前会跑 `flutter analyze` 与 `flutter test`，测试不通过则不发布。
- 安装包当前使用调试签名（`android/app/build.gradle.kts` 中 release 使用 debug keys），可直接装机；上架应用商店前需换成正式签名。
- CI 在海外运行，工作流里通过 `PUB_HOSTED_URL=https://pub.dev` 切回官方依赖源（本地锁文件用的是国内镜像）。

## 目录结构

```
lib/
  main.dart                     应用入口：加载数据后启动
  app.dart                      MaterialApp 与主题装配
  home_shell.dart               底部导航框架（首页 / 功课 / 明细）
  models/
    practice_session.dart       一次功课记录（开始、结束、遍数、逐次时间偏移）
    practice_settings.dart      功课设置与皮肤选择
  data/
    practice_store.dart         数据仓库：计数、撤销、归档、删除、导入导出、持久化
    practice_stats.dart         统计推导（今日/累计/连续天数/近七日）
    practice_history.dart       明细推导（按天分组与汇总）
    practice_backup.dart        明细记录的备份格式（编解码与校验）
    key_value_store.dart        键值存储抽象（便于测试替换）
    practice_scope.dart         把仓库共享给组件树
  voice/
    mantra_matcher.dart         按拼音比对判断是否圆满一遍
    mantra_voice_counter.dart   语音识别控制器（持续聆听、静音续听）
  pages/
    home_page.dart              首页：统计概览
    practice_page.dart          功课页：计数
    history_page.dart           明细页：按天列出每次功课
    settings_sheet.dart         功课设置面板
  widgets/
    practice_dial.dart          计数表盘与念珠绘制
    week_bar_chart.dart         近七日柱状图
    recitation_sheet.dart       逐次持咒时间面板
    stat_tile.dart              统计卡片
  theme/
    app_skin.dart               两套皮肤的色板与皮肤模式枚举
    app_theme.dart              由皮肤生成 Material 主题
  utils/date_formats.dart       中文日期与时长格式化
test/                           统计、仓库、皮肤、页面交互、语音、备份测试
```

## 数据说明

数据保存在本机 `shared_preferences`（键名 `ngy_zhunti_practice_v1`，JSON 结构），不联网、不上传。

- 每次计数先在内存中生效并立即刷新界面，写入磁盘做了 600ms 防抖，应用退到后台时会立即落盘。
- **每一次持咒的时间点都会保存**：存的是相对本次功课开始时间的毫秒偏移（而不是绝对时间戳），可显著压缩体积。按每天 108 遍估算约 1.6 KB/天、1080 遍约 16 KB/天，长年累积请留意存档大小；如需按时间归档，可以再加保留策略。
- 进行中的功课也会保存，重新打开应用后可以接着计数。
- **跨天自动归档**：若在次日继续计数，上一天的功课会自动结为一条记录，归入原本的日期，统计不会串日。
- 统计口径：连续天数从今天（今天还没持咒时从昨天）往前累计，遇到没有记录的日子即停止。
- 兼容性：早期版本只记录了总遍数，这类记录仍能正常读取与统计，只是看不到逐次时间点。
- **导出与导入**：设置里的「导出明细记录」把全部记录转成一段文本（只含记录、不含设置），可粘贴保存；「导入恢复」粘贴该文本后可选合并（按 id 去重追加）或覆盖（替换本地记录）。备份里的进行中功课会在本地没有正在进行的记录时恢复，不会打断当前计数。
- **语音计数**：应用只拿到系统识别出的文字做拼音比对，不保存、不上传任何音频。

## 备注

- 计数表盘在横竖屏下都会自适应尺寸；皮肤可跟随系统，也可在设置里锁定浅色或深色。
- 待办想法：念满整串时的磬声提示音、保持屏幕常亮、功课回向记录。这些都需要额外依赖，暂未引入。
