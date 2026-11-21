// src/app/api/accounts/expense-accounts/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function GET() {
  return proxyAuthedGet("/expense-accounts", "expense_accounts");
}

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/expense-accounts", "create_expense_account");
}
