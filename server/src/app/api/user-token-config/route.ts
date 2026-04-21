import { NextRequest, NextResponse } from 'next/server';
import { requireRedis } from '@/lib/redis';
import {
  evaluateUserTokenAccess,
  getUserTokenPolicy,
  listUserTokenPolicies,
  normalizeUserToken,
  normalizeUserTokenValidity,
  upsertUserTokenPolicy,
  USER_TOKEN_LENGTH,
  USER_TOKEN_VALIDITY_PERMANENT,
} from '@/lib/user-token';
import { resolveUserTokenFromRequest } from '@/lib/user-context';

export const dynamic = 'force-dynamic';

function isAdminAuthorized(request: NextRequest): boolean {
  const expected = process.env.USER_TOKEN_ADMIN_SECRET;
  if (!expected) return false;
  const actual = request.headers.get('x-admin-secret');
  return actual === expected;
}

export async function GET(request: NextRequest) {
  try {
    const redisClient = requireRedis('user token config storage is unavailable: Redis env is not configured');

    const shouldListAll = request.nextUrl.searchParams.get('all') === '1';
    if (shouldListAll) {
      if (!isAdminAuthorized(request)) {
        return NextResponse.json({ error: 'admin unauthorized' }, { status: 403 });
      }

      const policies = await listUserTokenPolicies(redisClient);
      return NextResponse.json({ policies });
    }

    const resolved = await resolveUserTokenFromRequest(request);
    if (resolved.errorMessage || !resolved.userToken) {
      return NextResponse.json(
        {
          token: null,
          accessState: 'invalid',
          reason: resolved.errorMessage ?? `用户标识无效，需要 ${USER_TOKEN_LENGTH} 位字母或数字`,
          policy: null,
        },
        { status: 200 }
      );
    }

    const token = resolved.userToken;
    const access = await evaluateUserTokenAccess(redisClient, token);
    const policy = access.policy ?? (await getUserTokenPolicy(redisClient, token));

    return NextResponse.json({
      token,
      accessState: access.state,
      reason: access.reason,
      policy,
    });
  } catch (error) {
    console.error('Failed to get user token config:', error);
    return NextResponse.json({ error: 'Failed to get user token config' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    if (!isAdminAuthorized(request)) {
      return NextResponse.json({ error: 'admin unauthorized' }, { status: 403 });
    }

    const body = (await request.json()) as {
      token?: string;
      validity?: string;
      expiresAt?: string;
    };

    const token = normalizeUserToken(body?.token);
    if (!token) {
      return NextResponse.json(
        { error: `token 必须是 ${USER_TOKEN_LENGTH} 位字母或数字` },
        { status: 400 }
      );
    }

    const validity = normalizeUserTokenValidity(body?.validity);
    if (!validity) {
      return NextResponse.json(
        { error: 'validity 必须是 permanent 或 until' },
        { status: 400 }
      );
    }

    const redisClient = requireRedis('user token config storage is unavailable: Redis env is not configured');

    const policy = await upsertUserTokenPolicy(redisClient, {
      token,
      validity,
      expiresAt: validity === USER_TOKEN_VALIDITY_PERMANENT ? undefined : body?.expiresAt,
    });

    const access = await evaluateUserTokenAccess(redisClient, token);
    return NextResponse.json({
      policy,
      accessState: access.state,
      reason: access.reason,
    });
  } catch (error) {
    return NextResponse.json({ error: String(error) }, { status: 400 });
  }
}
