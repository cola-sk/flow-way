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

  console.log('🚀 Uploading APK to Vercel Blob...');
  const fileBuffer = fs.readFileSync(apkPath);
  const fileName = 'flow-way-latest.apk';
  
  try {
    const blob = await put(fileName, fileBuffer, {
      access: 'public',
      addRandomSuffix: false, // 保持固定文件名便于下载
      contentType: 'application/vnd.android.package-archive',
      token: token,
    });

    console.log('✅ Upload successful!');
    console.log('🔗 Blob URL:', blob.url);
    console.log('--------------------------------------------------');
    console.log('You can now download the APK via the API endpoint:');
    console.log('/api/download');
    console.log('--------------------------------------------------');
  } catch (error) {
    console.error('❌ Upload failed:', error);
    process.exit(1);
  }
}

uploadApk();
