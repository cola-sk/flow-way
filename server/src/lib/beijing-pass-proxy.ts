import { NextRequest, NextResponse } from 'next/server';
import { requireActiveUserTokenFromRequest } from './user-context';

type BeijingPassOperation = 'state-list' | 'submit-apply';

const UPSTREAM_BASE_URL = 'https://jjz.jtgl.beijing.gov.cn';
const UPSTREAM_PATHS: Record<BeijingPassOperation, string> = {
  'state-list': '/pro/applyRecordController/stateList',
  'submit-apply': '/pro/applyRecordController/insertApplyRecord',
};

const MINI_PROGRAM_ORIGIN = 'https://servicewechat.com/wx8b273767f4c3c6f2/';
const MINI_PROGRAM_REFERER =
  'https://servicewechat.com/wx8b273767f4c3c6f2/123/page-frame.html';
const UPSTREAM_USER_AGENT =
  'Mozilla/5.0 (Linux; Android 12; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/95.0.4638.74 Mobile Safari/537.36 MMWEBID/1234 MicroMessenger/8.0.18.2040(0x28001235) Process/appbrand0 WeChat/arm64 Weixin NetType/WIFI Language/zh_CN ABI/arm64';
const MAX_BODY_BYTES = 24 * 1024;

export function beijingPassPreflightResponse(): NextResponse {
  return new NextResponse(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-user-token',
      'Access-Control-Max-Age': '86400',
    },
  });
}

function isJsonObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Proxies a fixed set of Beijing-pass endpoints for the Web client.
 * The browser cannot call the upstream directly because it does not allow CORS.
 */
export async function proxyBeijingPassRequest(
  request: NextRequest,
  operation: BeijingPassOperation
): Promise<NextResponse> {
  const userTokenGuard = await requireActiveUserTokenFromRequest(request);
  if (!userTokenGuard.ok) {
    return userTokenGuard.response!;
  }

  const authorization = request.headers.get('authorization')?.trim();
  if (!authorization) {
    return NextResponse.json({ error: 'Authorization is required' }, { status: 400 });
  }

  const bodyText = await request.text();
  if (bodyText.length > MAX_BODY_BYTES) {
    return NextResponse.json({ error: 'Request body is too large' }, { status: 413 });
  }

  let body: Record<string, unknown>;
  try {
    const parsed = bodyText.length === 0 ? {} : JSON.parse(bodyText);
    if (!isJsonObject(parsed)) {
      return NextResponse.json({ error: 'Request body must be a JSON object' }, { status: 400 });
    }
    body = parsed;
  } catch {
    return NextResponse.json({ error: 'Request body must be valid JSON' }, { status: 400 });
  }

  try {
    const upstream = await fetch(`${UPSTREAM_BASE_URL}${UPSTREAM_PATHS[operation]}`, {
      method: 'POST',
      cache: 'no-store',
      signal: AbortSignal.timeout(45000),
      headers: {
        Authorization: authorization,
        'Content-Type': 'application/json;charset=UTF-8',
        Accept: 'application/json, text/plain, */*',
        Origin: MINI_PROGRAM_ORIGIN,
        Referer: MINI_PROGRAM_REFERER,
        'User-Agent': UPSTREAM_USER_AGENT,
      },
      body: JSON.stringify(body),
    });

    const responseBody = await upstream.text();
    return new NextResponse(responseBody, {
      status: upstream.status,
      headers: {
        'Content-Type': upstream.headers.get('content-type') ?? 'application/json; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    });
  } catch {
    return NextResponse.json({ error: '北京进京证服务暂时不可用' }, { status: 502 });
  }
}
