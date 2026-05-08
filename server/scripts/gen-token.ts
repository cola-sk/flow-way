import { config } from 'dotenv';

config({ path: '.env.local' });
config();

import { randomInt } from 'crypto';
import { requireRedis } from '../src/lib/redis';
import {
  evaluateUserTokenAccess,
  upsertUserTokenPolicy,
  USER_TOKEN_VALIDITY_UNTIL,
  USER_TOKEN_REGEX,
} from '../src/lib/user-token';

const TOKEN_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_';
const TOKEN_LENGTH = 16;

function generateToken(): string {
  let token = '';
  for (let i = 0; i < TOKEN_LENGTH; i++) {
    token += TOKEN_CHARS[randomInt(TOKEN_CHARS.length)];
  }
  return token;
}

function printUsage(): void {
  console.log('Usage:');
  console.log('  pnpm run gen-token -- --days <n>');
  console.log('  pnpm run gen-token -- --until <datetime>');
  console.log('');
  console.log('Examples:');
  console.log('  pnpm run gen-token -- --days 30');
  console.log('  pnpm run gen-token -- --until 2026-12-31T23:59:59+08:00');
}

function parseArgs(): { expiresAt: string } {
  const args = process.argv.slice(2);
  const daysIdx = args.indexOf('--days');
  const untilIdx = args.indexOf('--until');

  if (daysIdx !== -1) {
    const daysStr = args[daysIdx + 1];
    const days = Number(daysStr);
    if (!Number.isFinite(days) || days <= 0) {
      throw new Error(`--days 必须是正整数，收到：${daysStr}`);
    }
    const expiresAt = new Date(Date.now() + days * 86_400_000).toISOString();
    return { expiresAt };
  }

  if (untilIdx !== -1) {
    const untilStr = args[untilIdx + 1];
    const ms = Date.parse(untilStr);
    if (!Number.isFinite(ms)) {
      throw new Error(`--until 必须是可解析的时间字符串，例如 2026-12-31T23:59:59+08:00，收到：${untilStr}`);
    }
    return { expiresAt: new Date(ms).toISOString() };
  }

  printUsage();
  process.exit(1);
}

async function main(): Promise<void> {
  const { expiresAt } = parseArgs();

  const token = generateToken();
  // 理论上不会失败，但做一次断言以保证格式正确
  if (!USER_TOKEN_REGEX.test(token)) {
    throw new Error(`生成的 token 格式异常：${token}`);
  }

  const redis = requireRedis('user token config storage is unavailable: Redis env is not configured');

  const policy = await upsertUserTokenPolicy(redis, {
    token,
    validity: USER_TOKEN_VALIDITY_UNTIL,
    expiresAt,
  });

  const access = await evaluateUserTokenAccess(redis, token);

  console.log('[gen-token] done');
  console.log(`[gen-token] token:          ${policy.token}`);
  console.log(`[gen-token] validity:       ${policy.validity}`);
  console.log(`[gen-token] expiresAt(UTC): ${policy.expiresAt}`);
  console.log(`[gen-token] accessState:    ${access.state}`);
  console.log(`[gen-token] reason:         ${access.reason}`);
}

main().catch((error) => {
  console.error('[gen-token] failed:', error);
  process.exit(1);
});
