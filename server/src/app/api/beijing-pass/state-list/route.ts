import { NextRequest } from 'next/server';
import {
  beijingPassPreflightResponse,
  proxyBeijingPassRequest,
} from '@/lib/beijing-pass-proxy';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  return proxyBeijingPassRequest(request, 'state-list');
}

export function OPTIONS() {
  return beijingPassPreflightResponse();
}
