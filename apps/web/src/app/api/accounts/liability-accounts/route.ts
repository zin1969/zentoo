// src/app/api/accounts/liability-accounts/route.ts

import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

export async function GET() {
  const requestId = crypto.randomUUID();
  log("liability_accounts.request_received", { requestId });

  const res = await apiFetch("/liability-accounts", {
    headers: { "X-Request-Id": requestId }
  });

  log("liability_accounts.rails_response", { requestId, status: res.status });

  const data = await res.json().catch(() => null);

  return Response.json(data, { status: res.status });
}
