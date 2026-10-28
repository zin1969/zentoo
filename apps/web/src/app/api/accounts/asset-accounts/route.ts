// src/app/api/accounts/asset-accounts/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";

export async function GET() {
  return proxyAuthedGet("/asset-accounts", "asset_accounts");
}
