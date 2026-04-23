import { list } from '@vercel/blob';
import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    // 列出所有 blob，查找名为 flow-way-latest.apk 的文件
    const { blobs } = await list({
      prefix: 'flow-way-latest.apk',
      limit: 1,
    });

    const latestBlob = blobs.find(b => b.pathname === 'flow-way-latest.apk');

    if (!latestBlob) {
      return NextResponse.json(
        { error: 'No APK found. Please run the upload script first.' },
        { status: 404 }
      );
    }

    // 重定向到最新的下载链接
    return NextResponse.redirect(latestBlob.url);
  } catch (error) {
    console.error('Failed to resolve download link:', error);
    return NextResponse.json(
      { error: 'Internal Server Error' },
      { status: 500 }
    );
  }
}
