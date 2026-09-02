// src/app/api/accounts/asset-accounts/route.ts

import { apiFetch } from "@/lib/rails/apiFetch";
import { log } from "@/lib/logging/logger";

export async function GET() {
  const requestId = crypto.randomUUID();
  log("asset_accounts.request_received", { requestId });

  const res = await apiFetch("/asset-accounts", {
    headers: { "X-Request-Id": requestId }
  });

  log("asset_accounts.rails_response", { requestId, status: res.status });

  return Response.json(await res.json());
}
