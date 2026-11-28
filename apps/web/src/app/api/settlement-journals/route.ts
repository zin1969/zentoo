// src/app/api/settlement-journals/route.ts

import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/settlement-journals", "create_settlement_journal");
}
