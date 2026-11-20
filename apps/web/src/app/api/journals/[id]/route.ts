// src/app/api/journals/[id]/route.ts

import { clearToken, getToken, setToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";
import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

// 仕訳の削除を Rails に中継する。成功時の Rails は本文を返さない（204）ので、
// 新しいトークンは本文の next_token ではなく X-Next-Token ヘッダで受け取る。
export async function DELETE(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  const { id } = await params;

  // Rails のパスに埋め込むので、数字以外は中継しない
  if (!/^\d+$/.test(id)) {
    return Response.json({ error: "journal_not_found" }, { status: 404 });
  }

  const requestId = crypto.randomUUID();
  log("delete_journal.request_received", { requestId });

  const token = await getToken();

  const res = await apiFetch(`/journals/${id}`, {
    method: "DELETE",
    headers: {
      Authorization: `Bearer ${token ?? ""}`,
      "X-Request-Id": requestId
    }
  });

  log("delete_journal.rails_response", { requestId, status: res.status });

  if (res.status === 401) {
    await clearToken();
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const nextToken = res.headers.get("x-next-token");
  if (nextToken) {
    await setToken(nextToken);
  }

  if (res.status === 204) {
    return new Response(null, { status: 204 });
  }

  const text = await res.text();

  try {
    return Response.json(JSON.parse(text), { status: res.status });
  } catch {
    log("delete_journal.rails_response_unparseable", { requestId, status: res.status });

    return Response.json(
      { code: "UNEXPECTED_ERROR", message: "サーバーでエラーが発生しました。" },
      { status: 502 }
    );
  }
}
