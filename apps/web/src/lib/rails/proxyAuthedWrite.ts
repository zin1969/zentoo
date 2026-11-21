import { clearToken, getToken, setToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";
import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

type WriteMethod = "POST" | "PUT" | "DELETE";

// 認証が必要な Rails の書き込み API を中継する Route Handler 用の共通処理。
// 別のサイトからの書き込みを拒否し（Origin の確認）、保持している JWT を Authorization ヘッダーに載せる。
// 新しい JWT は、本文の next_token か、本文の無い応答（204）では X-Next-Token ヘッダで受け取り、Cookie を更新する。
export async function proxyAuthedWrite(
  req: Request,
  method: WriteMethod,
  path: string,
  event: string
): Promise<Response> {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  const requestId = crypto.randomUUID();
  log(`${event}.request_received`, { requestId });

  const body = method === "DELETE" ? undefined : JSON.stringify(await req.json());
  const token = await getToken();

  const res = await apiFetch(path, {
    method,
    headers: {
      Authorization: `Bearer ${token ?? ""}`,
      "X-Request-Id": requestId
    },
    body
  });

  log(`${event}.rails_response`, { requestId, status: res.status });

  if (res.status === 401) {
    await clearToken();
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const headerToken = res.headers.get("x-next-token");

  if (res.status === 204) {
    if (headerToken) await setToken(headerToken);
    return new Response(null, { status: 204 });
  }

  const text = await res.text();

  try {
    const data = JSON.parse(text);
    const nextToken = data?.next_token ?? headerToken;
    if (nextToken) await setToken(nextToken);

    return Response.json(data, { status: res.status });
  } catch {
    log(`${event}.rails_response_unparseable`, { requestId, status: res.status });

    return Response.json(
      { code: "UNEXPECTED_ERROR", message: "サーバーでエラーが発生しました。" },
      { status: 502 }
    );
  }
}

// Rails のパスに埋め込む ID。数字以外は中継しない
export function isNumericId(id: string) {
  return /^\d+$/.test(id);
}
