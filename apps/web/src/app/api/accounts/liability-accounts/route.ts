// src/app/api/accounts/liability-accounts/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";

export async function GET() {
  return proxyAuthedGet("/liability-accounts", "liability_accounts");
}
