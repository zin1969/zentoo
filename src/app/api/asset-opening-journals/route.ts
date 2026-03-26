// src/app/api/asset-opening-journals/route.ts

import { cookies } from "next/headers";

export async function POST(req: Request) {
  const body = await req.json();

  // 🔥 ここを修正
  const cookieStore = await cookies();

  // 👇 ここにログ
  //const token = cookieStore.get("token")?.value;
  const token = "dummy-token"
  console.log("🔥 token:", token);

  console.log("🔥 request body:", body);

  const res = await fetch("http://api:3000/asset-opening-journals", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });

  // 🔥 ここを修正
  const text = await res.text();

  console.log("Rails raw response:", text);

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
