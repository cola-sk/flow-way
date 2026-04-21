import { config } from 'dotenv';

config({ path: '.env.local' });
config();

import { requireRedis } from '../src/lib/redis';
import {
  evaluateUserTokenAccess,
  normalizeUserToken,
  upsertUserTokenPolicy,
  USER_TOKEN_VALIDITY_UNTIL,
} from '../src/lib/user-token';

function printUsage(): void {
  console.log('Usage: pnpm run set-token-expiry -- <token> <expiresAt>');
  console.log('Example: pnpm run set-token-expiry -- liuzhetz20190618 2026-12-31T23:59:59+08:00');
}

async function main(): Promise<void> {
  const tokenArg = process.argv[2]?.trim();
  const expiresAtArg = process.argv[3]?.trim();

  if (!tokenArg || !expiresAtArg) {
    printUsage();
    process.exit(1);
  }

  const token = normalizeUserToken(tokenArg);
  if (!token) {
    throw new Error('token 无效：必须是16位字母或数字');
  }

  const expiresAtMs = Date.parse(expiresAtArg);
  if (!Number.isFinite(expiresAtMs)) {
    throw new Error('expiresAt 无效：必须是可解析的时间字符串，例如 2026-12-31T23:59:59+08:00');
  }

  const normalizedExpiresAt = new Date(expiresAtMs).toISOString();
  const redis = requireRedis('user token config storage is unavailable: Redis env is not configured');

  const policy = await upsertUserTokenPolicy(redis, {
    token,
    validity: USER_TOKEN_VALIDITY_UNTIL,
    expiresAt: normalizedExpiresAt,
  });

  const access = await evaluateUserTokenAccess(redis, token);

  console.log('[set-token-expiry] done');
  console.log(`[set-token-expiry] token: ${policy.token}`);
  console.log(`[set-token-expiry] validity: ${policy.validity}`);
  console.log(`[set-token-expiry] expiresAt(UTC): ${policy.expiresAt}`);
  console.log(`[set-token-expiry] accessState: ${access.state}`);
  console.log(`[set-token-expiry] reason: ${access.reason}`);
}

main().catch((error) => {
  console.error('[set-token-expiry] failed:', error);
  process.exit(1);
});
