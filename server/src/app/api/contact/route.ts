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
          wechatId: '',
          xianyuUrl: '',
        },
      },
      { status: 500 }
    );
  }
}
