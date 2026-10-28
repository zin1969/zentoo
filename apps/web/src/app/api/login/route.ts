// src/app/api/login/route.ts

import { setToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";
import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

export async function POST(req: Request) {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  const requestId = crypto.randomUUID();
  log("login.request_received", { requestId });

  const body = await req.json().catch(() => null);

  const res = await apiFetch("/login", {
    method: "POST",
    headers: { "X-Request-Id": requestId },
    body: JSON.stringify({ name: body?.name, password: body?.password })
  });

  // パスワードを含むリクエスト内容はログに出さない
  log("login.rails_response", { requestId, status: res.status });

  if (res.status === 429) {
    return Response.json({ error: "too_many_requests" }, { status: 429 });
  }

  const data = await res.json().catch(() => null);

  // 発行された JWT は Browser に返さず、httpOnly Cookie にのみ保持する（7.1章）
  if (res.status === 201 && typeof data?.token === "string") {
    await setToken(data.token);
    return Response.json({ ok: true });
  }

  if (res.status === 401) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  return Response.json(
    { code: "UNEXPECTED_ERROR", message: "サーバーでエラーが発生しました。" },
    { status: 502 }
  );
}
