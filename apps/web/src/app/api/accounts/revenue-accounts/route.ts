// src/app/api/accounts/revenue-accounts/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function GET() {
  return proxyAuthedGet("/revenue-accounts", "revenue_accounts");
}

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/revenue-accounts", "create_revenue_account");
}
