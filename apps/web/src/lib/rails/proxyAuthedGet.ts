import { clearToken, getToken, setToken } from "@/lib/cookies/tokenCookie";
import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

// 認証が必要な Rails の GET API を中継する Route Handler 用の共通処理。
// 保持している JWT を Authorization ヘッダーに載せ、401 の場合は Cookie を破棄する（7.2章）。
// マスタ取得のように配列を返す API は本文に next_token を持てないため、Rails は新しい JWT を
// X-Next-Token ヘッダで返す。受け取ったら Cookie を更新し、画面を開いている間は期限切れにしない。
export async function proxyAuthedGet(path: string, event: string): Promise<Response> {
  const requestId = crypto.randomUUID();
  log(`${event}.request_received`, { requestId });

  const token = await getToken();

  const res = await apiFetch(path, {
    headers: {
      Authorization: `Bearer ${token ?? ""}`,
      "X-Request-Id": requestId
    }
  });

  log(`${event}.rails_response`, { requestId, status: res.status });

  if (res.status === 401) {
    await clearToken();
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const nextToken = res.headers.get("x-next-token");
  if (nextToken) {
    await setToken(nextToken);
  }

  const text = await res.text();

  try {
    return Response.json(JSON.parse(text), { status: res.status });
  } catch {
    log(`${event}.rails_response_unparseable`, { requestId, status: res.status });

    return Response.json(
      { code: "UNEXPECTED_ERROR", message: "サーバーでエラーが発生しました。" },
      { status: 502 }
    );
  }
}
