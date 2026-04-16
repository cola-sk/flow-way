import { NextResponse } from 'next/server';
import { signTencentUrl } from '@/lib/tencent-sign';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const keyword = searchParams.get('keyword')?.trim();
  const lat = searchParams.get('lat');
  const lng = searchParams.get('lng');

  if (!keyword) {
    return NextResponse.json({ error: 'keyword is required' }, { status: 400 });
  }

  // 若传入当前位置则以附近 5km 为优先范围，否则在全国搜索
  const boundary =
    lat && lng
      ? `nearby(${lat},${lng},5000)`
      : 'region(北京,0)';

  const baseUrl = new URL('https://apis.map.qq.com/ws/place/v1/search/');
  baseUrl.searchParams.set('keyword', keyword);
  baseUrl.searchParams.set('boundary', boundary);
  baseUrl.searchParams.set('page_size', '8');

  const signedUrl = signTencentUrl(baseUrl);

  const res = await fetch(signedUrl, {
    cache: 'no-store',
  });
  if (!res.ok) {
    return NextResponse.json({ error: 'upstream error' }, { status: 502 });
  }

  const json = await res.json();
  if (json.status !== 0) {
    return NextResponse.json({ results: [] });
  }

  const results = (json.data ?? []).map((item: {
    title: string;
    address: string;
    location: { lat: number; lng: number };
  }) => ({
    name: item.title,
    address: item.address,
    lat: item.location.lat,
    lng: item.location.lng,
  }));

  return NextResponse.json({ results });
}
