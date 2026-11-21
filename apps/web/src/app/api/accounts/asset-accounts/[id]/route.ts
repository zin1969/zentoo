// src/app/api/accounts/asset-accounts/[id]/route.ts

import { isNumericId, proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

type Context = { params: Promise<{ id: string }> };

const NOT_FOUND = { error: "asset_account_not_found" };

export async function PUT(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "PUT", `/asset-accounts/${id}`, "update_asset_account");
}

export async function DELETE(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "DELETE", `/asset-accounts/${id}`, "delete_asset_account");
}
