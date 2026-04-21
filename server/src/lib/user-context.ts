import { NextRequest, NextResponse } from 'next/server';
import { requireRedis } from './redis';
import {
  evaluateUserTokenAccess,
  getOrCreateDefaultUserToken,
  normalizeUserToken,
  USER_TOKEN_LENGTH,
} from './user-token';

const USER_TOKEN_QUERY_KEY = 'userToken';
const USER_TOKEN_BODY_KEY = 'userToken';
const USER_TOKEN_HEADER_KEY = 'x-user-token';

function pickRawToken(request: NextRequest, bodyToken?: unknown): unknown {
  if (bodyToken !== undefined) {
    return bodyToken;
  }

  const queryValue = request.nextUrl.searchParams.get(USER_TOKEN_QUERY_KEY);
  if (queryValue !== null) {
    return queryValue;
  }

  const headerValue = request.headers.get(USER_TOKEN_HEADER_KEY);
  if (headerValue !== null) {
    return headerValue;
  }

  return undefined;
}

export type ResolvedUserToken = {
  userToken?: string;
  errorMessage?: string;
};

export type RequireActiveUserTokenResult = {
  ok: boolean;
  userToken?: string;
  response?: NextResponse;
};

function buildTokenInvalidResponse(message: string): NextResponse {
  return NextResponse.json(
    {
      errorCode: 'TOKEN_INVALID',
      errorMessage: message,
    },
    { status: 403 }
  );
}

function buildTokenExpiredResponse(message: string, expiresAt?: string): NextResponse {
  return NextResponse.json(
    {
      errorCode: 'TOKEN_EXPIRED',
      errorMessage: message,
      expiresAt,
    },
    { status: 403 }
  );
}

export async function resolveUserTokenFromRequest(
  request: NextRequest,
  body?: Record<string, unknown>
): Promise<ResolvedUserToken> {
  const raw = pickRawToken(request, body?.[USER_TOKEN_BODY_KEY]);
  if (raw !== undefined) {
    const normalized = normalizeUserToken(raw);
    if (!normalized) {
      return {
        errorMessage: `用户标识无效，需要 ${USER_TOKEN_LENGTH} 位字母、数字或下划线`,
      };
    }
    return { userToken: normalized };
  }

  const redisClient = requireRedis('user token storage is unavailable: Redis env is not configured');
  const userToken = await getOrCreateDefaultUserToken(redisClient);
  return { userToken };
}

export async function requireActiveUserTokenFromRequest(
  request: NextRequest,
  body?: Record<string, unknown>
): Promise<RequireActiveUserTokenResult> {
  const resolved = await resolveUserTokenFromRequest(request, body);
  if (resolved.errorMessage || !resolved.userToken) {
    return {
      ok: false,
      response: buildTokenInvalidResponse(
        resolved.errorMessage ?? `用户标识无效，需要 ${USER_TOKEN_LENGTH} 位字母、数字或下划线`
      ),
    };
  }

  const redisClient = requireRedis('user token storage is unavailable: Redis env is not configured');
  const access = await evaluateUserTokenAccess(redisClient, resolved.userToken);

  if (access.state === 'active') {
    return {
      ok: true,
      userToken: resolved.userToken,
    };
  }

  if (access.state === 'expired') {
    return {
      ok: false,
      response: buildTokenExpiredResponse(access.reason, access.policy?.expiresAt),
    };
  }

  return {
    ok: false,
    response: buildTokenInvalidResponse(access.reason),
  };
}
