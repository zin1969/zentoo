// src/app/api/budget-reports/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";

export async function GET(req: Request) {
  const date = new URL(req.url).searchParams.get("date");
  const query = date ? `?${new URLSearchParams({ date })}` : "";

  return proxyAuthedGet(`/budget-reports${query}`, "budget_reports");
}
