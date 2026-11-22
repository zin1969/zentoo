// src/app/api/income-journals/[id]/route.ts

import { isNumericId, proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function PUT(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json({ error: "journal_not_found" }, { status: 404 });

  return proxyAuthedWrite(req, "PUT", `/income-journals/${id}`, "update_income_journal");
}
