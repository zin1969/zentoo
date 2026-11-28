// src/app/api/budgets/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function GET() {
  return proxyAuthedGet("/budgets", "budgets");
}

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/budgets", "create_budget");
}
