import { WayPoint } from '@/types/route';

// In-memory storage for development.
// Replace with persistent storage in production.
export const wayPointsStorage = new Map<string, WayPoint>();
