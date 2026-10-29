// src/app/api/journals/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";

// Rails に中継するクエリパラメータ（これ以外は捨てる）
const ALLOWED_PARAMS = ["from", "to", "page"] as const;

export async function GET(req: Request) {
  const incoming = new URL(req.url).searchParams;
  const forwarded = new URLSearchParams();

  for (const name of ALLOWED_PARAMS) {
    const value = incoming.get(name);
    if (value) forwarded.set(name, value);
  }

  const query = forwarded.toString();

  return proxyAuthedGet(query ? `/journals?${query}` : "/journals", "journals");
}
