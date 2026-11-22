// src/app/api/recurring-entries/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function GET() {
  return proxyAuthedGet("/recurring-entries", "recurring_entries");
}

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/recurring-entries", "create_recurring_entry");
}
