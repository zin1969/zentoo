// src/app/api/logout/route.ts

import { clearToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";

export async function POST(req: Request) {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  await clearToken();

  return Response.json({ ok: true });
}
