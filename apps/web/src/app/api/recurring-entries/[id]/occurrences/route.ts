// src/app/api/recurring-entries/[id]/occurrences/route.ts

import { isNumericId, proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

type Context = { params: Promise<{ id: string }> };

// 決まった支払いの回を、確かめた金額で仕訳にする
export async function POST(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json({ error: "recurring_entry_not_found" }, { status: 404 });

  return proxyAuthedWrite(req, "POST", `/recurring-entries/${id}/occurrences`, "register_recurring_occurrence");
}
