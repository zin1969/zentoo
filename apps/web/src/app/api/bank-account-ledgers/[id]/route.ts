// src/app/api/bank-account-ledgers/[id]/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { isNumericId } from "@/lib/rails/proxyAuthedWrite";

// Rails に中継するクエリパラメータ（これ以外は捨てる）
const ALLOWED_PARAMS = ["from", "to"] as const;

export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json({ error: "asset_account_not_found" }, { status: 404 });

  const incoming = new URL(req.url).searchParams;
  const forwarded = new URLSearchParams();

  for (const name of ALLOWED_PARAMS) {
    const value = incoming.get(name);
    if (value) forwarded.set(name, value);
  }

  const query = forwarded.toString();

  return proxyAuthedGet(`/bank-account-ledgers/${id}${query ? `?${query}` : ""}`, "bank_account_ledger");
}
