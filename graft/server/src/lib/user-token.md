# server/src/lib/user-token.ts

- UserTokenValidity · type · L15-L17 — type UserTokenValidity = | typeof USER_TOKEN_VALIDITY_PERMANENT | typeof USER_TOKEN_VALIDITY_UNTIL;
- UserTokenPolicy · type · L19-L25 — type UserTokenPolicy = { token: string; validity: UserTokenValidity; expiresAt?: string; createdAt: string; updatedAt: string; };
- TokenAccessState · type · L27-L27 — type TokenAccessState = 'active' | 'expired' | 'invalid';
- TokenAccessResult · type · L29-L33 — type TokenAccessResult = { state: TokenAccessState; policy?: UserTokenPolicy; reason: string; };
- normalizeUserToken · function · L35-L40 — function normalizeUserToken(value: unknown): string | null
- isValidUserToken · function · L42-L44 — function isValidUserToken(value: unknown): boolean
- normalizeUserTokenValidity · function · L46-L54 — function normalizeUserTokenValidity(value: unknown): UserTokenValidity | null
- generateUserToken · function · L56-L63 — function generateUserToken(): string
- isValidIsoDateTime · function · L65-L71 — function isValidIsoDateTime(value: unknown): value is string
- tomorrowSameTimeIso · function · L73-L75 — function tomorrowSameTimeIso(nowMs = Date.now()): string
- normalizeUserTokenPolicy · function · L77-L112 — function normalizeUserTokenPolicy(raw: unknown): UserTokenPolicy | null
- getUserTokenPolicy · function · L114-L125 — async function getUserTokenPolicy( redis: Redis, token: string ): Promise<UserTokenPolicy | null>
- upsertUserTokenPolicy · function · L127-L164 — async function upsertUserTokenPolicy( redis: Redis, input: { token: string; validity: UserTokenValidity; expiresAt?: string; } ): Promise<UserTokenPolicy>
- listUserTokenPolicies · function · L166-L176 — async function listUserTokenPolicies(redis: Redis): Promise<UserTokenPolicy[]>
- ensureDefaultUserTokenPolicy · function · L178-L188 — async function ensureDefaultUserTokenPolicy(redis: Redis, token: string): Promise<void>
- ensureFirstLaunchDefaultTokenPolicy · function · L190-L204 — async function ensureFirstLaunchDefaultTokenPolicy( redis: Redis, nowMs = Date.now() ): Promise<void>
- evaluateUserTokenAccess · function · L206-L261 — async function evaluateUserTokenAccess( redis: Redis, token: string, nowMs = Date.now() ): Promise<TokenAccessResult>
- getOrCreateDefaultUserToken · function · L263-L274 — async function getOrCreateDefaultUserToken(redis: Redis): Promise<string>
