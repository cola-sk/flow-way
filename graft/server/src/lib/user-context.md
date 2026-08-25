# server/src/lib/user-context.ts

- pickRawToken · function · L14-L30 — function pickRawToken(request: NextRequest, bodyToken?: unknown): unknown
- ResolvedUserToken · type · L32-L35 — type ResolvedUserToken = { userToken?: string; errorMessage?: string; };
- RequireActiveUserTokenResult · type · L37-L41 — type RequireActiveUserTokenResult = { ok: boolean; userToken?: string; response?: NextResponse; };
- buildTokenInvalidResponse · function · L43-L51 — function buildTokenInvalidResponse(message: string): NextResponse
- buildTokenExpiredResponse · function · L53-L62 — function buildTokenExpiredResponse(message: string, expiresAt?: string): NextResponse
- resolveUserTokenFromRequest · function · L64-L82 — async function resolveUserTokenFromRequest( request: NextRequest, body?: Record<string, unknown> ): Promise<ResolvedUserToken>
- requireActiveUserTokenFromRequest · function · L84-L119 — async function requireActiveUserTokenFromRequest( request: NextRequest, body?: Record<string, unknown> ): Promise<RequireActiveUserTokenResult>
