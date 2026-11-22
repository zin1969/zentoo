// src/app/api/tag-reports/[id]/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { isNumericId } from "@/lib/rails/proxyAuthedWrite";

export async function GET(req: Request, { params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json({ error: "tag_not_found" }, { status: 404 });

  const year = new URL(req.url).searchParams.get("year");
  const query = year ? `?${new URLSearchParams({ year })}` : "";

  return proxyAuthedGet(`/tag-reports/${id}${query}`, "tag_report");
}
