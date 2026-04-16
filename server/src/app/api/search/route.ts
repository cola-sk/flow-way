import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

const TENCENT_KEY = process.env.TENCENT_MAP_KEY!;

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

  const url = new URL('https://apis.map.qq.com/ws/place/v1/search/');
  url.searchParams.set('keyword', keyword);
  url.searchParams.set('boundary', boundary);
  url.searchParams.set('page_size', '8');
  url.searchParams.set('key', TENCENT_KEY);

  const res = await fetch(url.toString(), {
    headers: { Referer: 'https://flow-way.tz0618.uk' },
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
