// src/app/api/transfer-journals/route.ts

import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/transfer-journals", "create_transfer_journal");
}
