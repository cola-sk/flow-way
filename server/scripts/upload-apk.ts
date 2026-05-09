import { put } from '@vercel/blob';
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

  // 获取命令行参数中的版本标签
  const versionTag = process.argv[2];
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

    // 如果提供了版本号，同时更新版本清单
    if (versionTag) {
      const manifest = JSON.stringify({
        version: versionTag,
        apkUrl: blob.url,
        releasedAt: new Date().toISOString(),
      });
      const manifestBlob = await put('flow-way-version.json', manifest, {
        access: 'public',
        addRandomSuffix: false,
        allowOverwrite: true,
        contentType: 'application/json',
        token: token,
      });
      console.log('✅ Version manifest updated:', manifestBlob.url);
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
