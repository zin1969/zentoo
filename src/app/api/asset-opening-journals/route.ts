// src/app/api/asset-opening-journals/route.ts

import { getToken, setToken, clearToken } from "@/lib/cookies/tokenCookie";

export async function POST(req: Request) {
  const body = await req.json();

  const token = await getToken();

  const res = await fetch("http://api:3000/asset-opening-journals", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token ?? ""}`,
      "Content-Type": "application/json"
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
