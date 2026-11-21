// src/app/api/accounts/credit-cards/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function GET() {
  return proxyAuthedGet("/credit-cards", "credit_cards");
}

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/credit-cards", "create_credit_card");
}
