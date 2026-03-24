// src/app/api/asset-opening-journals/route.ts

import { cookies } from "next/headers";

export async function POST(req: Request) {
  const body = await req.json();
  const cookieStore = cookies();

  const token = cookieStore.get("token")?.value;

  const res = await fetch("http://api:3000/asset-opening-journals", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });

  const data = await res.json();

  // ✅ token更新（401以外）
  if (res.status !== 401 && data?.next_token) {
    cookieStore.set("token", data.next_token, {
      httpOnly: true,
      path: "/"
    });
  }

  return Response.json(data, { status: res.status });
}
