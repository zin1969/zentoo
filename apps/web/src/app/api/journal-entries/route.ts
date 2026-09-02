// src/app/api/journal-entries/route.ts

import { getToken, setToken, clearToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";
import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

export async function POST(req: Request) {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  const requestId = crypto.randomUUID();
  log("journal_entries.request_received", { requestId });

  const body = await req.json();

  const token = await getToken();

  const res = await apiFetch("/journal-entries", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token ?? ""}`,
      "X-Request-Id": requestId
    },
    body: JSON.stringify(body)
  });

  log("journal_entries.rails_response", { requestId, status: res.status });

  const text = await res.text();

  try {
    const data = JSON.parse(text);

    if (res.status === 401) {
      await clearToken();
    } else if (data?.next_token) {
      await setToken(data.next_token);
    }

    return Response.json(data, { status: res.status });

  } catch (e) {
    log("journal_entries.rails_response_unparseable", {
      requestId,
      status: res.status,
      body: text
    });

    return Response.json(
      { code: "UNEXPECTED_ERROR", message: "サーバーでエラーが発生しました。" },
      { status: 502 }
    );
  }
}
