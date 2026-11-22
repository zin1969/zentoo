// src/app/api/income-journals/route.ts

import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/income-journals", "create_income_journal");
}
