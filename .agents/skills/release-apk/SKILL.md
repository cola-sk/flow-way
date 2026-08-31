---
name: release-apk
description: 构建 flow-way Android APK 并发布。分为两种模式：正式版（连接生产接口，走完整升版+构建+上传+更新 version.json 流程）和 Beta 版（连接指定 Preview 接口，用于测试验证，可上传或安装到手机）。当用户说"发版"、"release"、"打包"、"升级版本"、"更新 changelog"时触发正式版流程；当用户说"打 beta 包"、"发 beta"、"测试包"、"更新 beta"时触发 Beta 版流程。
metadata:
  pattern: tool-wrapper
  domain: flow-way/release
  output-format: terminal-output
  interaction: multi-turn
---

你是 flow-way 的发版工程师，负责管理版本号、构建 APK、上传分发，以及维护首页更新日志。

## 先确认

发版前需确认：
1. **发版类型**：正式版 还是 Beta 版？
2. **版本升级类型**（仅正式版需要）：patch（修复/小优化）/ minor（新功能）/ major（重大更新）/ 或直接指定 x.y.z
3. **本次更新亮点**：用一句话描述核心改动，供写更新日志用
4. **是否更新 changelog**：若有用户可见的功能变化，必须更新
5. **联系方式与闲鱼链接**：若闲鱼地址或微信号有变更，可通过 `pnpm run sync-contact` 将 `server/src/config/contact.json` 同步保存到数据库
6. **Beta 接口地址**（仅 Beta 版需要）：默认使用项目 `server/package.json` 中 `build-apk:beta` 配置的 `https://flow-way-preview.tz0618.uk`，也可指定其他 Preview URL

---

## 正式版流程（连接生产接口）

适用于面向用户的正式发布。产物通过 `/api/download` 对外分发。

### 步骤一：更新 Changelog

**触发场景**：若有用户可见的功能变化，必须先更新 changelog。

**文件路径**：`server/src/app/changelog.ts`

在 `CHANGELOG` 数组**顶部**插入新条目（最新版排第一）：

```typescript
{
  version: 'x.y.z',           // 与发版版本一致
  date: 'YYYY-MM-DD',         // 发版日期
  title: '...',               // 一句话标题，用户角度，例如："更顺手的导航体验"
  highlights: [               // 核心亮点，2-4 条，面向用户，非技术描述
    '功能描述...',
  ],
  improvements: [             // 可选：次要改进，折叠显示
    '改进描述...',
  ],
  fixes: [                    // 可选：问题修复
    '修复描述...',
  ],
},
```

**写作原则**：
- `title`：像产品发布标题，简洁有感染力，避免"修复了 bug"这类说法
- `highlights`：站在用户角度描述「你可以做什么」，不写实现细节
- `improvements`/`fixes`：稍技术，折叠展示，不必过分修饰

### 步骤二：一键发版（构建 + 上传）

**触发场景**：用户说"发版"、"release"、"打包并上传"。

**命令目录**：`server/`

```bash
# patch 升版（默认，1.0.1 → 1.0.2）
pnpm run release

# minor 升版（1.0.x → 1.1.0）
pnpm run release:minor

# major 升版（1.x.x → 2.0.0）
pnpm run release:major

# 直接指定版本号
npx tsx scripts/release.ts 1.2.3
```

**脚本做了什么**：
1. 读取 `pubspec.yaml` 当前版本，按规则计算新版本号
2. 自动将 `build` 号 +1，写回 `pubspec.yaml`
3. 执行 `flutter build apk --release --build-name=x.y.z --build-number=N`
4. 上传 `flow-way-x.y.z.apk` 到 Vercel Blob（永久存档）
5. 更新 `flow-way-version.json`（下载 API 读取此文件查询最新版）

**完成后用户可用的下载地址**：
- 最新版：`/api/download`
- 指定版本：`/api/download?version=x.y.z`

### 步骤三：部署 Server

```bash
git push  # Vercel 自动部署，使新的 changelog 和 version.json 生效
```

### 步骤四：验证

访问 `/api/download` 确认可下载最新版 APK。

---

## Beta 版流程（连接 Preview 接口）

适用于内部测试验证，连接非生产环境的接口。必须严格按以下顺序执行：

### 步骤一：确认分支

```bash
git branch --show-current
```

当前分支必须是 `preview`。如果不是，停止流程并询问用户，不要自动切换或创建分支。

### 步骤二：检查并提交改动

先检查工作区和差异，只提交本次 Beta 更新相关文件；不要把无关改动一起提交。提交必须发生在构建之前。

```bash
git status --short --branch
git diff --check
git add <本次改动文件>
git commit -m "<本次改动说明>"
```

如果没有需要提交的改动，应明确告知用户并继续询问是否仍要构建；不要为了发 Beta 创建空提交。

### 步骤三：构建 Beta Release APK

默认使用项目已有脚本（它会注入 Preview API 和 `IS_BETA=true`）：

```bash
pnpm --dir server run build-apk:beta
```

该命令等价于在项目根目录执行：

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://flow-way-preview.tz0618.uk \
  --dart-define=IS_BETA=true
```

若用户指定其他 Preview URL，使用该 URL 替换 `API_BASE_URL`，并保留 `IS_BETA=true`。构建产物通常位于 `build/app/outputs/flutter-apk/app-release.apk`。

### 步骤四：构建完成后询问交付方式

构建成功后必须询问用户选择以下一种方式，不能默认上传或默认安装：

1. **上传 Beta APK**
2. **安装到手机**

如果选择上传：

```bash
pnpm --dir server run upload-apk:beta
```

产物会以 `flow-way-beta.apk` 上传，可通过 `/api/download?version=beta` 下载。Beta 上传不会更新 `flow-way-version.json`。

如果选择安装：

```bash
flutter devices
adb -s <device_id> install -r build/app/outputs/flutter-apk/app-release.apk
```

设备多于一个时，先询问用户要安装到哪台设备；没有 Android 设备时，提示用户连接设备，不要擅自改为上传。

### 步骤五：最后推送

仅当构建以及用户选择的上传/安装动作成功后，才执行最后的推送：

```bash
git push origin preview
```

如果构建、上传或安装失败，不要推送，先报告失败原因并等待用户决定是否继续。

> **注意**：Beta 版不升级版本号、不更新 `flow-way-version.json`、不影响正式版下载入口。

---

## 通用操作

### 仅上传 APK（跳过构建）

**触发场景**：APK 已构建，只需上传。

```bash
cd server/
pnpm run upload-apk              # 正式版：不带版本标签
pnpm run upload-apk -- 1.2.3    # 正式版：带版本标签（同时更新 version.json）
pnpm run upload-apk:beta        # Beta 版：上传为 beta 标签
```

### 查看当前版本

```bash
grep '^version:' pubspec.yaml
```

---

## 文件结构

| 文件 | 作用 |
|---|---|
| `pubspec.yaml` | Flutter 版本号，格式 `x.y.z+build`（仅正式版流程修改） |
| `server/scripts/release.ts` | 正式版一键发版主脚本 |
| `server/scripts/upload-apk.ts` | 单独上传 APK |
| `server/src/app/changelog.ts` | 馴页更新日志数据 |
| `server/src/app/page.tsx` | 驯页（自动读取 changelog） |
| Vercel Blob: `flow-way-version.json` | 正式版最新版本清单，下载 API 读取 |
| Vercel Blob: `flow-way-x.y.z.apk` | 各正式版 APK 存档 |
| Vercel Blob: `flow-way-beta.apk` | Beta 版 APK（每次上传覆盖） |

---

## 注意事项

- 构建前确保 Flutter 环境正常（`flutter doctor`）
- `BLOB_READ_WRITE_TOKEN` 必须配置在 `server/.env.local`
- 正式版版本号只升不降；如需回滚，直接用 `/api/download?version=旧版本号` 下载旧 APK
- `pubspec.yaml` 修改后记得 `git commit`，保持版本号与代码同步
- Beta 版每次上传会覆盖上一次的 `flow-way-beta.apk`，不会生成版本存档
