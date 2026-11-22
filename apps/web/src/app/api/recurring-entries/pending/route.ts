// src/app/api/recurring-entries/pending/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";

// 今月の末日までの、まだ登録も飛ばしもしていない回
export async function GET() {
  return proxyAuthedGet("/recurring-entries/pending", "pending_recurring_occurrences");
}
