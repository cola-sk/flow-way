# server/src/lib/kv-logger.ts

- LogData · interface · L4-L8 — interface LogData extends Record<string, any>
- kvLog · function · L13-L33 — function kvLog(event: string, data: LogData)
- getLogMetadata · function · L38-L47 — function getLogMetadata(request: NextRequest, userToken?: string): LogData
