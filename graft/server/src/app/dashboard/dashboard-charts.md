# server/src/app/dashboard/dashboard-charts.tsx

- UserToken · interface · L6-L14 — interface UserToken
- TokenFilter · type · L16-L16 — type TokenFilter = 'all' | 'active' | 'expiring' | 'expired' | 'invalid';
- formatDate · function · L24-L35 — function formatDate(value: string | null, options?: Intl.DateTimeFormatOptions)
- getExpiryInfo · function · L37-L51 — function getExpiryInfo(token: UserToken)
- getStateInfo · function · L53-L58 — function getStateInfo(token: UserToken)
- Badge · function · L60-L74 — function Badge({ children, tone }: { children: React.ReactNode; tone: string })
- SummaryCard · function · L76-L83 — function SummaryCard({ label, value, tone = '#0f766e' }: { label: string; value: number; tone?: string })
- DashboardCharts · function · L85-L231 — function DashboardCharts()
- fetchUserTokens · function · L93-L106 — fetchUserTokens = async ()
