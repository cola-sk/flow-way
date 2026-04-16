import { NextResponse } from 'next/server';
import { signTencentUrl } from '@/lib/tencent-sign';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const keyword = searchParams.get('keyword')?.trim();
  const lat = searchParams.get('lat');
  const lng = searchParams.get('lng');

  if (!keyword) {
    return NextResponse.json({ suggestions: [] });
  }

  const baseUrl = new URL('https://apis.map.qq.com/ws/place/v1/suggestion/');
  baseUrl.searchParams.set('keyword', keyword);
  if (lat && lng) baseUrl.searchParams.set('location', `${lat},${lng}`);
  baseUrl.searchParams.set('region', '北京');
  baseUrl.searchParams.set('page_size', '8');

  const signedUrl = signTencentUrl(baseUrl);
  console.log('[suggest] signed URL:', signedUrl);

  const res = await fetch(signedUrl, {
    cache: 'no-store',
  });

  if (!res.ok) {
    console.error('[suggest] upstream HTTP error:', res.status, res.statusText);
    return NextResponse.json({ suggestions: [] });
  }

  const json = await res.json();
  console.log('[suggest] tencent status:', json.status, json.message);
  if (json.status !== 0) {
    console.error('[suggest] tencent error response:', JSON.stringify(json));
    return NextResponse.json({ suggestions: [] });
  }

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

  console.log('[suggest] returning', suggestions.length, 'results');
  return NextResponse.json({ suggestions });
}
