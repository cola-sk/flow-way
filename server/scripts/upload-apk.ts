import { put, list } from '@vercel/blob';
import fs from 'fs';
import path from 'path';
import { config } from 'dotenv';
import { fileURLToPath } from 'url';

// 兼容 ES Module 的 __dirname
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 加载环境变量
config({ path: path.resolve(__dirname, '../.env.local') });

async function uploadApk() {
  // APK 路径通常在 flutter 工程的 build 目录下
  // 假设脚本在 server/scripts 下运行，工程根目录在 ../../
  const apkPath = path.resolve(__dirname, '../../build/app/outputs/flutter-apk/app-release.apk');
  
  console.log(`Checking for APK at: ${apkPath}`);
  
  if (!fs.existsSync(apkPath)) {
    console.error('❌ APK file not found!');
    console.error('Please run "flutter build apk --release" first in the root directory.');
    process.exit(1);
  }

  const token = process.env.BLOB_READ_WRITE_TOKEN;
  if (!token) {
    console.error('❌ BLOB_READ_WRITE_TOKEN is not set in .env.local');
    process.exit(1);
  }

  // 获取命令行参数中的版本标签（过滤掉 pnpm 透传的 '--' 分隔符）
  const versionTag = process.argv.slice(2).find(a => a !== '--');
  let fileName = 'flow-way-latest.apk';
  
  if (versionTag) {
    fileName = `flow-way-${versionTag}.apk`;
    console.log(`📌 Version tag specified: ${versionTag}`);
  } else {
    console.log(`📌 No version tag specified, using default: latest`);
  }

  console.log('🚀 Uploading APK to Vercel Blob...');
  const fileBuffer = fs.readFileSync(apkPath);
  
  try {
    // 上传带版本号的文件
    const blob = await put(fileName, fileBuffer, {
      access: 'public',
      addRandomSuffix: false,
      allowOverwrite: true,
      contentType: 'application/vnd.android.package-archive',
      token: token,
    });
    console.log('✅ Versioned upload:', blob.url);

    // 如果提供了版本号，同时更新版本清单（仅当新版本 >= 当前记录版本时）
    if (versionTag) {
      // 读取当前 version.json
      let currentVersion: string | null = null;
      try {
        const { blobs } = await list({ prefix: 'flow-way-version.json', limit: 1 });
        const manifestBlob = blobs.find(b => b.pathname === 'flow-way-version.json');
        if (manifestBlob) {
          const res = await fetch(manifestBlob.url, { cache: 'no-store' });
          if (res.ok) {
            const data = await res.json() as { version: string };
            currentVersion = data.version;
          }
        }
      } catch { /* 读取失败则忽略，视为首次发布 */ }

      // 比较版本：将 x.y.z 转成数字数组逐段比较
      const toNums = (v: string) => v.split('.').map(Number);
      const isNewer = (a: string, b: string) => {
        const [a0, a1, a2] = toNums(a);
        const [b0, b1, b2] = toNums(b);
        return a0 > b0 || (a0 === b0 && a1 > b1) || (a0 === b0 && a1 === b1 && a2 >= b2);
      };

      if (currentVersion && !isNewer(versionTag, currentVersion)) {
        console.warn(`⚠️  跳过更新 version.json：指定版本 ${versionTag} 低于当前记录版本 ${currentVersion}`);
        console.warn('   若确实要回滚，请手动修改 version.json。');
      } else {
        const manifest = JSON.stringify({
          version: versionTag,
          apkUrl: blob.url,
          releasedAt: new Date().toISOString(),
        });
        const manifestResult = await put('flow-way-version.json', manifest, {
          access: 'public',
          addRandomSuffix: false,
          allowOverwrite: true,
          contentType: 'application/json',
          token: token,
        });
        console.log('✅ Version manifest updated:', manifestResult.url);
        if (currentVersion) {
          console.log(`   ${currentVersion} → ${versionTag}`);
        }
      }
    }

    console.log('--------------------------------------------------');
    console.log('Download latest : /api/download');
    if (versionTag) {
      console.log(`Download v${versionTag}: /api/download?version=${versionTag}`);
    }
    console.log('--------------------------------------------------');
  } catch (error) {
    console.error('❌ Upload failed:', error);
    process.exit(1);
  }
}

uploadApk();
