import { config } from 'dotenv';

config({ path: '.env.local' });
config();

import { requireRedis } from '../src/lib/redis';
import {
  evaluateUserTokenAccess,
  getUserTokenPolicy,
  normalizeUserToken,
  upsertUserTokenPolicy,
  USER_TOKEN_VALIDITY_UNTIL,
} from '../src/lib/user-token';

function printUsage(): void {
  console.log('Usage:');
  console.log('  pnpm run set-token-expiry -- <token> --days <n>');
  console.log('  pnpm run set-token-expiry -- <token> --until <datetime>');
  console.log('');
  console.log('Examples:');
  console.log('  pnpm run set-token-expiry -- liuzhetz20190618 --days 30');
  console.log('  pnpm run set-token-expiry -- liuzhetz20190618 --until 2026-12-31T23:59:59+08:00');
  console.log('');
  console.log('Notes:');
  console.log('  --days  从当前有效期（已过期则从现在）延长 N 天');
  console.log('  --until 直接设置到期时间');
}

async function main(): Promise<void> {
  let args = process.argv.slice(2);
  
  // 跳过 pnpm 传入的 '--' 分隔符
  if (args[0] === '--') {
    args = args.slice(1);
  }

  const tokenArg = args[0]?.trim();
  const daysIdx = args.indexOf('--days');
  const untilIdx = args.indexOf('--until');

  if (!tokenArg || (daysIdx === -1 && untilIdx === -1)) {
    printUsage();
    process.exit(1);
  }

  const token = normalizeUserToken(tokenArg);
  if (!token) {
    throw new Error('token 无效：必须是16位字母、数字或下划线');
  }

  const redis = requireRedis('user token config storage is unavailable: Redis env is not configured');

  let expiresAt: string;

  if (daysIdx !== -1) {
    const daysStr = args[daysIdx + 1];
    const days = Number(daysStr);
    if (!Number.isFinite(days) || days <= 0) {
      throw new Error(`--days 必须是正整数，收到：${daysStr}`);
    }

    // 从当前有效期延长；若无有效期或已过期，则从现在起算
    const existing = await getUserTokenPolicy(redis, token);
    const existingExpiresMs = existing?.expiresAt ? Date.parse(existing.expiresAt) : NaN;
    const baseMs = Number.isFinite(existingExpiresMs) && existingExpiresMs > Date.now()
      ? existingExpiresMs
      : Date.now();

    expiresAt = new Date(baseMs + days * 86_400_000).toISOString();
    console.log(`[set-token-expiry] base: ${new Date(baseMs).toISOString()}`);
    console.log(`[set-token-expiry] extend: +${days} days`);
  } else {
    const untilStr = args[untilIdx + 1];
    const ms = Date.parse(untilStr);
    if (!Number.isFinite(ms)) {
      throw new Error(`--until 必须是可解析的时间字符串，例如 2026-12-31T23:59:59+08:00，收到：${untilStr}`);
    }
    expiresAt = new Date(ms).toISOString();
  }

  const policy = await upsertUserTokenPolicy(redis, {
    token,
    validity: USER_TOKEN_VALIDITY_UNTIL,
    expiresAt,
  });

  const access = await evaluateUserTokenAccess(redis, token);

  console.log('[set-token-expiry] done');
  console.log(`[set-token-expiry] token:          ${policy.token}`);
  console.log(`[set-token-expiry] validity:       ${policy.validity}`);
  console.log(`[set-token-expiry] expiresAt(UTC): ${policy.expiresAt}`);
  console.log(`[set-token-expiry] accessState:    ${access.state}`);
  console.log(`[set-token-expiry] reason:         ${access.reason}`);
}

main().catch((error) => {
  console.error('[set-token-expiry] failed:', error);
  process.exit(1);
});
