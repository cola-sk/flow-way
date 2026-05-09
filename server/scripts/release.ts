/**
 * release.ts — 自动升版本、构建 release APK 并上传到 Vercel Blob
 *
 * 用法 (在项目根目录或 server/ 目录均可):
 *   npx tsx scripts/release.ts patch      # 1.0.0 → 1.0.1  (默认)
 *   npx tsx scripts/release.ts minor      # 1.0.1 → 1.1.0
 *   npx tsx scripts/release.ts major      # 1.1.0 → 2.0.0
 *   npx tsx scripts/release.ts 1.2.3      # 直接指定完整版本号
 */

import { put } from '@vercel/blob';
import { execSync } from 'child_process';
import { config } from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 加载环境变量（server/.env.local）
config({ path: path.resolve(__dirname, '../.env.local') });

// ---------- 路径 ----------
// 脚本在 server/scripts/，项目根在 ../../
const rootDir = path.resolve(__dirname, '../../');
const pubspecPath = path.join(rootDir, 'pubspec.yaml');
const apkPath = path.join(
  rootDir,
  'build/app/outputs/flutter-apk/app-release.apk'
);

// ---------- 读取当前版本 ----------
function readVersion(): { semver: string; build: number } {
  const content = fs.readFileSync(pubspecPath, 'utf-8');
  const match = content.match(/^version:\s*(\d+\.\d+\.\d+)\+(\d+)/m);
  if (!match) throw new Error('无法从 pubspec.yaml 解析版本号');
  return { semver: match[1], build: parseInt(match[2], 10) };
}

// ---------- 计算新版本 ----------
function bumpSemver(current: string, bump: string): string {
  // 如果是 x.y.z 格式直接返回
  if (/^\d+\.\d+\.\d+$/.test(bump)) return bump;

  const [major, minor, patch] = current.split('.').map(Number);
  switch (bump) {
    case 'major': return `${major + 1}.0.0`;
    case 'minor': return `${major}.${minor + 1}.0`;
    case 'patch': return `${major}.${minor}.${patch + 1}`;
    default:
      throw new Error(
        `未知参数: "${bump}"，请使用 major | minor | patch | x.y.z`
      );
  }
}

// ---------- 写回 pubspec.yaml ----------
function writeVersion(newSemver: string, newBuild: number) {
  const content = fs.readFileSync(pubspecPath, 'utf-8');
  const updated = content.replace(
    /^version:\s*\d+\.\d+\.\d+\+\d+/m,
    `version: ${newSemver}+${newBuild}`
  );
  fs.writeFileSync(pubspecPath, updated, 'utf-8');
}

// ---------- 上传 APK + 写版本清单 ----------
async function uploadApk(semver: string, build: number, fileBuffer: Buffer) {
  const token = process.env.BLOB_READ_WRITE_TOKEN;
  if (!token) throw new Error('BLOB_READ_WRITE_TOKEN 未配置（server/.env.local）');

  const versionedName = `flow-way-${semver}.apk`;

  console.log(`\n⬆️  上传 ${versionedName} ...`);
  const versionedBlob = await put(versionedName, fileBuffer, {
    access: 'public',
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: 'application/vnd.android.package-archive',
    token,
  });
  console.log(`✅ APK 上传完成: ${versionedBlob.url}`);

  // 写版本清单（轻量 JSON，供 /api/download 查询最新版本）
  const manifest = JSON.stringify({
    version: semver,
    build,
    apkUrl: versionedBlob.url,
    releasedAt: new Date().toISOString(),
  });
  console.log(`\n⬆️  更新版本清单 flow-way-version.json ...`);
  const manifestBlob = await put('flow-way-version.json', manifest, {
    access: 'public',
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: 'application/json',
    token,
  });
  console.log(`✅ 版本清单已更新: ${manifestBlob.url}`);

  return { versionedUrl: versionedBlob.url };
}

// ---------- 主流程 ----------
async function main() {
  const bump = process.argv[2] ?? 'patch';

  const { semver: currentSemver, build: currentBuild } = readVersion();
  const newSemver = bumpSemver(currentSemver, bump);
  const newBuild = currentBuild + 1;

  console.log(
    `🔖 版本升级: ${currentSemver}+${currentBuild}  →  ${newSemver}+${newBuild}`
  );

  // 1. 更新 pubspec.yaml
  writeVersion(newSemver, newBuild);
  console.log('✅ pubspec.yaml 已更新');

  // 2. 构建 APK
  console.log(`\n🏗️  flutter build apk --release ...`);
  execSync(
    `flutter build apk --release --build-name=${newSemver} --build-number=${newBuild}`,
    { cwd: rootDir, stdio: 'inherit' }
  );
  console.log('\n✅ APK 构建完成');

  // 3. 读取 APK 文件
  if (!fs.existsSync(apkPath)) {
    throw new Error(`APK 未找到: ${apkPath}`);
  }
  const fileBuffer = fs.readFileSync(apkPath);

  // 4. 上传 APK + 更新版本清单
  const { versionedUrl } = await uploadApk(newSemver, newBuild, fileBuffer);

  console.log('\n--------------------------------------------------');
  console.log(`🎉 发布完成！版本: ${newSemver}+${newBuild}`);
  console.log(`📦 APK 文件:  ${versionedUrl}`);
  console.log(`🔗 下载最新:  /api/download`);
  console.log(`🔗 下载指定:  /api/download?version=${newSemver}`);
  console.log('--------------------------------------------------');
}

main().catch((e) => {
  console.error('❌', e instanceof Error ? e.message : e);
  process.exit(1);
});
