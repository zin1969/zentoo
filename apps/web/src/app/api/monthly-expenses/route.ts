// src/app/api/monthly-expenses/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";

export async function GET(req: Request) {
  const month = new URL(req.url).searchParams.get("month");
  const query = month ? `?${new URLSearchParams({ month })}` : "";

  return proxyAuthedGet(`/monthly-expenses${query}`, "monthly_expenses");
}
