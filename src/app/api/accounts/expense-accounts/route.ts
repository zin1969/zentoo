// src/app/api/accounts/expense-accounts/route.ts

import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

export async function GET() {
  const requestId = crypto.randomUUID();
  log("expense_accounts.request_received", { requestId });

  const res = await apiFetch("/expense-accounts", {
    headers: { "X-Request-Id": requestId }
  });

  log("expense_accounts.rails_response", { requestId, status: res.status });

  const data = await res.json().catch(() => null);

  return Response.json(data, { status: res.status });
}
