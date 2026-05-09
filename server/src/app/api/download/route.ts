import { list } from '@vercel/blob';
import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = request.nextUrl;
    const version = searchParams.get('version');

    if (version) {
      // 指定版本：直接查找对应 APK
      const targetName = `flow-way-${version}.apk`;
      const { blobs } = await list({ prefix: targetName, limit: 1 });
      const blob = blobs.find(b => b.pathname === targetName);
      if (!blob) {
        return NextResponse.json(
          { error: `Version ${version} not found.` },
          { status: 404 }
        );
      }
      return NextResponse.redirect(blob.url);
    }

    // 未指定版本：读取 version.json 获取最新版本的 APK URL
    const { blobs: manifestBlobs } = await list({
      prefix: 'flow-way-version.json',
      limit: 1,
    });
    const manifestBlob = manifestBlobs.find(
      b => b.pathname === 'flow-way-version.json'
    );
    if (!manifestBlob) {
      return NextResponse.json(
        { error: 'No release found. Please run the release script first.' },
        { status: 404 }
      );
    }

    // 拉取清单内容
    const res = await fetch(manifestBlob.url, { cache: 'no-store' });
    if (!res.ok) throw new Error('Failed to fetch version manifest');
    const manifest = (await res.json()) as { version: string; apkUrl: string };

    // 直接重定向到清单中记录的 APK URL（避免二次 list 查询）
    return NextResponse.redirect(manifest.apkUrl);
  } catch (error) {
    console.error('Failed to resolve download link:', error);
    return NextResponse.json(
      { error: 'Internal Server Error' },
      { status: 500 }
    );
  }
}
