import { NextResponse } from 'next/server';

const TENCENT_KEY = process.env.TENCENT_MAP_KEY!;

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const keyword = searchParams.get('keyword')?.trim();
  const lat = searchParams.get('lat');
  const lng = searchParams.get('lng');

  if (!keyword) {
    return NextResponse.json({ suggestions: [] });
  }

  const url = new URL('https://apis.map.qq.com/ws/place/v1/suggestion/');
  url.searchParams.set('keyword', keyword);
  if (lat && lng) url.searchParams.set('location', `${lat},${lng}`);
  url.searchParams.set('region', '北京');
  url.searchParams.set('page_size', '8');
  url.searchParams.set('key', TENCENT_KEY);

  const res = await fetch(url.toString(), {
    headers: { Referer: 'https://flow-way.tz0618.uk' },
    next: { revalidate: 0 },
  });

  if (!res.ok) return NextResponse.json({ suggestions: [] });

  const json = await res.json();
  if (json.status !== 0) return NextResponse.json({ suggestions: [] });

  const suggestions = (json.data ?? []).map((item: {
    title: string;
    address: string;
    location: { lat: number; lng: number };
  }) => ({
    name: item.title,
    address: item.address ?? '',
    lat: item.location?.lat ?? 0,
    lng: item.location?.lng ?? 0,
  }));

  return NextResponse.json({ suggestions });
}
