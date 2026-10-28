// src/app/api/accounts/expense-accounts/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";

export async function GET() {
  return proxyAuthedGet("/expense-accounts", "expense_accounts");
}
