import { NextResponse } from 'next/server';
import { signTencentUrl } from '@/lib/tencent-sign';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const lat = Number(searchParams.get('lat'));
  const lng = Number(searchParams.get('lng'));

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return NextResponse.json({ error: 'lat/lng is required' }, { status: 400 });
  }

  try {
    const baseUrl = new URL('https://apis.map.qq.com/ws/geocoder/v1/');
    baseUrl.searchParams.set('location', `${lat},${lng}`);
    baseUrl.searchParams.set('get_poi', '0');

    const signedUrl = signTencentUrl(baseUrl);
    const res = await fetch(signedUrl, { cache: 'no-store' });
    if (!res.ok) {
      return NextResponse.json({ place: null }, { status: 502 });
    }

    const json = await res.json();
    if (json.status !== 0 || !json.result) {
      return NextResponse.json({ place: null });
    }

    const result = json.result as {
      address?: string;
      formatted_addresses?: {
        recommend?: string;
      };
      location?: { lat: number; lng: number };
    };

    const name =
      result.formatted_addresses?.recommend?.trim() ||
      result.address?.trim() ||
      '地图选点';

    return NextResponse.json({
      place: {
        name,
        address: result.address ?? '',
        lat: result.location?.lat ?? lat,
        lng: result.location?.lng ?? lng,
      },
    });
  } catch (error) {
    console.error('reverse geocode failed:', error);
    return NextResponse.json({ place: null }, { status: 500 });
  }
}
