// src/app/api/asset-opening-journals/route.ts

import { getToken, setToken, clearToken } from "@/lib/cookies/tokenCookie";
import { originGuardResponse } from "@/lib/csrf/originGuard";
import { apiFetch } from "@/lib/rails/apiFetch";

export async function POST(req: Request) {
  const originError = originGuardResponse(req);
  if (originError) return originError;

  const body = await req.json();

  const token = await getToken();

  const res = await apiFetch("/asset-opening-journals", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token ?? ""}`
    },
    body: JSON.stringify(body)
  });

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
    // 👇 HTMLそのまま返す（デバッグ用）
    return new Response(text, { status: res.status });
  }
}
