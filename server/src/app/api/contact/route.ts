import { NextResponse } from 'next/server';
import { getContactConfigFromDb } from '@/lib/contact-config';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const config = await getContactConfigFromDb();

    return NextResponse.json({
      success: true,
      data: {
        wechatId: config.wechatId,
        xianyuUrl: config.xianyuUrl,
        updatedAt: config.updatedAt,
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        data: {
          wechatId: 'kero_wi',
          xianyuUrl: 'https://m.tb.cn/h.RZUBs4W?tk=VoEy5pFEchA',
        },
      },
      { status: 500 }
    );
  }
}
