// src/app/api/accounts/asset-accounts/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function GET() {
  return proxyAuthedGet("/asset-accounts", "asset_accounts");
}

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/asset-accounts", "create_asset_account");
}
