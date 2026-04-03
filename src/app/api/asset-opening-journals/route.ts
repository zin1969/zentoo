// src/app/api/asset-opening-journals/route.ts

import { cookies } from "next/headers";

export async function POST(req: Request) {
  const body = await req.json();

  const cookieStore = await cookies();

  //const token = cookieStore.get("token")?.value;
  const token = "dummy-token"

  const res = await fetch("http://api:3000/asset-opening-journals", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });

  const text = await res.text();

  try {
    const data = JSON.parse(text);

    // token更新
    if (res.status !== 401 && data?.next_token) {
      cookieStore.set("token", data.next_token, {
        httpOnly: true,
        path: "/"
      });
    }

    return Response.json(data, { status: res.status });

  } catch (e) {
    // 👇 HTMLそのまま返す（デバッグ用）
    return new Response(text, { status: res.status });
  }
}
