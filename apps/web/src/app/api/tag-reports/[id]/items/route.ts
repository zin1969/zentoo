// src/app/api/tag-reports/[id]/items/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { isNumericId } from "@/lib/rails/proxyAuthedWrite";

export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json({ error: "tag_not_found" }, { status: 404 });

  const month = new URL(req.url).searchParams.get("month");
  const query = month ? `?${new URLSearchParams({ month })}` : "";

  return proxyAuthedGet(`/tag-reports/${id}/items${query}`, "tag_report_items");
}
