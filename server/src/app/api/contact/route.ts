import { list } from '@vercel/blob';
import { NextResponse } from 'next/server';
import contactConfig from '@/config/contact.json';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    let wechatId = contactConfig.wechatId || 'kero_wi';
    let xianyuUrl = contactConfig.xianyuUrl || 'https://m.tb.cn/h.RZUBs4W?tk=VoEy5pFEchA';
    let version = '';
    let releasedAt = '';

    try {
      const { blobs } = await list({
        prefix: 'flow-way-version.json',
        limit: 1,
      });
      const manifestBlob = blobs.find(b => b.pathname === 'flow-way-version.json');
      if (manifestBlob) {
        const res = await fetch(manifestBlob.url, { cache: 'no-store' });
        if (res.ok) {
          const data = await res.json() as {
            version?: string;
            releasedAt?: string;
            wechatId?: string;
            xianyuUrl?: string;
          };
          if (data.wechatId) wechatId = data.wechatId;
          if (data.xianyuUrl) xianyuUrl = data.xianyuUrl;
          if (data.version) version = data.version;
          if (data.releasedAt) releasedAt = data.releasedAt;
        }
      }
    } catch (e) {
      console.warn('Failed to fetch remote flow-way-version.json:', e);
    }

    return NextResponse.json({
      success: true,
      data: {
        wechatId,
        xianyuUrl,
        version,
        releasedAt,
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        data: {
          wechatId: contactConfig.wechatId || 'kero_wi',
          xianyuUrl: contactConfig.xianyuUrl || 'https://m.tb.cn/h.RZUBs4W?tk=VoEy5pFEchA',
        },
      },
      { status: 500 }
    );
  }
}
