import { Redis } from '@upstash/redis';

export const USER_TOKEN_LENGTH = 16;
export const USER_TOKEN_REGEX = /^[A-Za-z0-9_]{16}$/;
export const USER_META_HASH_KEY = 'user-config-meta';
export const USER_TOKEN_POLICY_HASH_KEY = 'user-token-policies';
export const FIRST_LAUNCH_DEFAULT_USER_TOKEN = 'test_token_v2026';

const DEFAULT_USER_TOKEN_FIELD = 'default-user-token';

const TOKEN_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

export const USER_TOKEN_VALIDITY_PERMANENT = 'permanent' as const;
export const USER_TOKEN_VALIDITY_UNTIL = 'until' as const;
export type UserTokenValidity =
  | typeof USER_TOKEN_VALIDITY_PERMANENT
  | typeof USER_TOKEN_VALIDITY_UNTIL;

export type UserTokenPolicy = {
  token: string;
  validity: UserTokenValidity;
  expiresAt?: string;
  createdAt: string;
  updatedAt: string;
};

export type TokenAccessState = 'active' | 'expired' | 'invalid';

export type TokenAccessResult = {
  state: TokenAccessState;
  policy?: UserTokenPolicy;
  reason: string;
};

export function normalizeUserToken(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!USER_TOKEN_REGEX.test(trimmed)) return null;
  return trimmed;
}

export function isValidUserToken(value: unknown): boolean {
  return normalizeUserToken(value) !== null;
}

export function normalizeUserTokenValidity(value: unknown): UserTokenValidity | null {
  if (value === USER_TOKEN_VALIDITY_PERMANENT) {
    return USER_TOKEN_VALIDITY_PERMANENT;
  }
  if (value === USER_TOKEN_VALIDITY_UNTIL) {
    return USER_TOKEN_VALIDITY_UNTIL;
  }
  return null;
}

export function generateUserToken(): string {
  let token = '';
  for (let i = 0; i < USER_TOKEN_LENGTH; i++) {
    const idx = Math.floor(Math.random() * TOKEN_CHARS.length);
    token += TOKEN_CHARS[idx];
  }
  return token;
}

function isValidIsoDateTime(value: unknown): value is string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return false;
  }
  const t = Date.parse(value);
  return Number.isFinite(t);
}

function tomorrowSameTimeIso(nowMs = Date.now()): string {
  return new Date(nowMs + 24 * 60 * 60 * 1000).toISOString();
}

function normalizeUserTokenPolicy(raw: unknown): UserTokenPolicy | null {
  if (!raw || typeof raw !== 'object') {
    return null;
  }

  const obj = raw as Record<string, unknown>;
  const token = normalizeUserToken(obj.token);
  const validity = normalizeUserTokenValidity(obj.validity);
  const createdAt = isValidIsoDateTime(obj.createdAt) ? obj.createdAt : null;
  const updatedAt = isValidIsoDateTime(obj.updatedAt) ? obj.updatedAt : null;

  if (!token || !validity || !createdAt || !updatedAt) {
    return null;
  }

  if (validity === USER_TOKEN_VALIDITY_PERMANENT) {
    return {
      token,
      validity,
      createdAt,
      updatedAt,
    };
  }

  if (!isValidIsoDateTime(obj.expiresAt)) {
    return null;
  }

  return {
    token,
    validity,
    expiresAt: obj.expiresAt,
    createdAt,
    updatedAt,
  };
}

export async function getUserTokenPolicy(
  redis: Redis,
  token: string
): Promise<UserTokenPolicy | null> {
  const normalizedToken = normalizeUserToken(token);
  if (!normalizedToken) {
    return null;
  }

  const record = await redis.hget(USER_TOKEN_POLICY_HASH_KEY, normalizedToken);
  return normalizeUserTokenPolicy(record);
}

export async function upsertUserTokenPolicy(
  redis: Redis,
  input: {
    token: string;
    validity: UserTokenValidity;
    expiresAt?: string;
  }
): Promise<UserTokenPolicy> {
  const token = normalizeUserToken(input.token);
  if (!token) {
    throw new Error(`token 必须是 ${USER_TOKEN_LENGTH} 位字母、数字或下划线`);
  }

  const validity = normalizeUserTokenValidity(input.validity);
  if (!validity) {
    throw new Error('validity 必须是 permanent 或 until');
  }

  if (validity === USER_TOKEN_VALIDITY_UNTIL) {
    if (!isValidIsoDateTime(input.expiresAt)) {
      throw new Error('until 模式必须提供合法的 expiresAt ISO 时间');
    }
  }

  const nowIso = new Date().toISOString();
  const existing = await getUserTokenPolicy(redis, token);

  const policy: UserTokenPolicy = {
    token,
    validity,
    ...(validity === USER_TOKEN_VALIDITY_UNTIL ? { expiresAt: input.expiresAt } : {}),
    createdAt: existing?.createdAt ?? nowIso,
    updatedAt: nowIso,
  };

  await redis.hset(USER_TOKEN_POLICY_HASH_KEY, { [token]: policy });
  return policy;
}

export async function listUserTokenPolicies(redis: Redis): Promise<UserTokenPolicy[]> {
  const all = await redis.hgetall<Record<string, unknown>>(USER_TOKEN_POLICY_HASH_KEY);
  if (!all) {
    return [];
  }

  return Object.values(all)
    .map((item) => normalizeUserTokenPolicy(item))
    .filter((item): item is UserTokenPolicy => Boolean(item))
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

async function ensureDefaultUserTokenPolicy(redis: Redis, token: string): Promise<void> {
  const existing = await getUserTokenPolicy(redis, token);
  if (existing) {
    return;
  }

  await upsertUserTokenPolicy(redis, {
    token,
    validity: USER_TOKEN_VALIDITY_PERMANENT,
  });
}

export async function ensureFirstLaunchDefaultTokenPolicy(
  redis: Redis,
  nowMs = Date.now()
): Promise<void> {
  const existing = await getUserTokenPolicy(redis, FIRST_LAUNCH_DEFAULT_USER_TOKEN);
  if (existing) {
    return;
  }

  await upsertUserTokenPolicy(redis, {
    token: FIRST_LAUNCH_DEFAULT_USER_TOKEN,
    validity: USER_TOKEN_VALIDITY_UNTIL,
    expiresAt: tomorrowSameTimeIso(nowMs),
  });
}

export async function evaluateUserTokenAccess(
  redis: Redis,
  token: string,
  nowMs = Date.now()
): Promise<TokenAccessResult> {
  const normalizedToken = normalizeUserToken(token);
  if (!normalizedToken) {
    return {
      state: 'invalid',
      reason: `用户标识无效，需要 ${USER_TOKEN_LENGTH} 位字母、数字或下划线`,
    };
  }

  if (normalizedToken === FIRST_LAUNCH_DEFAULT_USER_TOKEN) {
    await ensureFirstLaunchDefaultTokenPolicy(redis, nowMs);
  }

  const policy = await getUserTokenPolicy(redis, normalizedToken);
  if (!policy) {
    return {
      state: 'invalid',
      reason: '用户标识不存在或未开通',
    };
  }

  if (policy.validity === USER_TOKEN_VALIDITY_PERMANENT) {
    return {
      state: 'active',
      policy,
      reason: 'ok',
    };
  }

  const expireMs = policy.expiresAt ? Date.parse(policy.expiresAt) : NaN;
  if (!Number.isFinite(expireMs)) {
    return {
      state: 'invalid',
      policy,
      reason: '用户标识有效期配置无效',
    };
  }

  if (nowMs > expireMs) {
    return {
      state: 'expired',
      policy,
      reason: '用户标识有效期已到，请续费',
    };
  }

  return {
    state: 'active',
    policy,
    reason: 'ok',
  };
}

export async function getOrCreateDefaultUserToken(redis: Redis): Promise<string> {
  await ensureFirstLaunchDefaultTokenPolicy(redis);

  const existing = await redis.hget<string>(USER_META_HASH_KEY, DEFAULT_USER_TOKEN_FIELD);
  if (existing !== FIRST_LAUNCH_DEFAULT_USER_TOKEN) {
    await redis.hset(USER_META_HASH_KEY, {
      [DEFAULT_USER_TOKEN_FIELD]: FIRST_LAUNCH_DEFAULT_USER_TOKEN,
    });
  }

  return FIRST_LAUNCH_DEFAULT_USER_TOKEN;
}
