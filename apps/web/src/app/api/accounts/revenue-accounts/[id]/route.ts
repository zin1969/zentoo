// src/app/api/accounts/revenue-accounts/[id]/route.ts

import { isNumericId, proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

type Context = { params: Promise<{ id: string }> };

const NOT_FOUND = { error: "revenue_account_not_found" };

export async function PUT(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "PUT", `/revenue-accounts/${id}`, "update_revenue_account");
}

export async function DELETE(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "DELETE", `/revenue-accounts/${id}`, "delete_revenue_account");
}
