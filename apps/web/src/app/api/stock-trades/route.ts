// src/app/api/stock-trades/route.ts

import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/stock-trades", "create_stock_trade");
}
