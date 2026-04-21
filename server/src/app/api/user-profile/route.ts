import { NextRequest, NextResponse } from 'next/server';
import { resolveUserTokenFromRequest } from '@/lib/user-context';
import {
  AVOID_ALGORITHM_V1_0,
  AVOID_ALGORITHM_V1_1_BETA_1,
  DEFAULT_AVOID_ALGORITHM_VERSION,
} from '@/lib/route';
import {
  evaluateUserTokenAccess,
  getUserTokenPolicy,
  USER_TOKEN_LENGTH,
} from '@/lib/user-token';
import { requireRedis } from '@/lib/redis';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const userContext = await resolveUserTokenFromRequest(request);

    let accessState: 'active' | 'expired' | 'invalid' = 'invalid';
    let reason = userContext.errorMessage ?? '用户标识无效';
    let policy: unknown = null;

    if (userContext.userToken) {
      const redisClient = requireRedis('user token storage is unavailable: Redis env is not configured');
      const access = await evaluateUserTokenAccess(redisClient, userContext.userToken);
      accessState = access.state;
      reason = access.reason;
      policy = access.policy ?? (await getUserTokenPolicy(redisClient, userContext.userToken));
    }

    return NextResponse.json({
      userToken: userContext.userToken ?? null,
      accessState,
      accessReason: reason,
      tokenPolicy: policy,
      userTokenLength: USER_TOKEN_LENGTH,
      avoidAlgorithmVersions: [AVOID_ALGORITHM_V1_0, AVOID_ALGORITHM_V1_1_BETA_1],
      defaultAvoidAlgorithmVersion: DEFAULT_AVOID_ALGORITHM_VERSION,
    });
  } catch (error) {
    console.error('Failed to get user profile:', error);
    return NextResponse.json(
      { error: 'Failed to get user profile' },
      { status: 500 }
    );
  }
}
