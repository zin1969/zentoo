// src/app/api/journal-entries/[id]/route.ts

import { getToken, setToken, clearToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";
import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

// お買い物の仕訳の修正を Rails に中継する。仕訳は作り直されるので、Rails は新しい journal_id を返す
export async function PUT(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  const { id } = await params;

  // Rails のパスに埋め込むので、数字以外は中継しない
  if (!/^\d+$/.test(id)) {
    return Response.json({ error: "journal_not_found" }, { status: 404 });
  }

  const requestId = crypto.randomUUID();
  log("update_journal_entry.request_received", { requestId });

  const body = await req.json();

  const token = await getToken();

  const res = await apiFetch(`/journal-entries/${id}`, {
    method: "PUT",
    headers: {
      Authorization: `Bearer ${token ?? ""}`,
      "X-Request-Id": requestId
    },
    body: JSON.stringify(body)
  });

  log("update_journal_entry.rails_response", { requestId, status: res.status });

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
    log("update_journal_entry.rails_response_unparseable", {
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
