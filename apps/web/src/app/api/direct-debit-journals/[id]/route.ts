// src/app/api/direct-debit-journals/[id]/route.ts

import { getToken, setToken, clearToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";
import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

// カードの引き落とし仕訳の日付の変更を Rails に中継する
export async function PUT(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  const { id } = await params;

  // Rails のパスに埋め込むので、数字以外は中継しない
  if (!/^\d+$/.test(id)) {
    return Response.json({ error: "journal_not_found" }, { status: 404 });
  }

  const requestId = crypto.randomUUID();
  log("update_direct_debit_date.request_received", { requestId });

  const body = await req.json();

  const token = await getToken();

  const res = await apiFetch(`/direct-debit-journals/${id}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token ?? ""}`,
      "X-Request-Id": requestId
    },
    body: JSON.stringify(body)
  });

  log("update_direct_debit_date.rails_response", { requestId, status: res.status });

  const text = await res.text();

  try {
    const data = JSON.parse(text);

    if (res.status === 401) {
      await clearToken();
    } else if (data?.next_token) {
      await setToken(data.next_token);
    }

    return Response.json(data, { status: res.status });

  } catch {
    log("update_direct_debit_date.rails_response_unparseable", {
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
