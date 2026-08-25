# server/src/app/dashboard/event-timeline-modal.tsx

- EventItem · interface · L5-L11 — interface EventItem
- EventTimelineModalProps · interface · L13-L16 — interface EventTimelineModalProps
- EventDetail · interface · L18-L22 — interface EventDetail
- toBool · function · L117-L124 — function toBool(value: unknown): boolean | undefined
- formatDistanceMeters · function · L126-L129 — function formatDistanceMeters(value: number): string
- formatDurationSeconds · function · L131-L134 — function formatDurationSeconds(value: number): string
- formatDetailValue · function · L136-L177 — function formatDetailValue(key: string, value: unknown): string
- buildEventDetails · function · L179-L201 — function buildEventDetails(event: EventItem): EventDetail[]
- getEventLabel · function · L203-L205 — function getEventLabel(event: string): string
- getEventColor · function · L207-L209 — function getEventColor(event: string): string
- EventTimelineModal · function · L211-L562 — function EventTimelineModal({ token, onClose }: EventTimelineModalProps)
- fetchEvents · function · L217-L229 — fetchEvents = async ()
- count · function · L234-L235 — count = (name: string, predicate?: (e: EventItem) => boolean)
