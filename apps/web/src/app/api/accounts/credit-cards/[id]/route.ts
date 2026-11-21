// src/app/api/accounts/credit-cards/[id]/route.ts

import { isNumericId, proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

type Context = { params: Promise<{ id: string }> };

const NOT_FOUND = { error: "credit_card_not_found" };

export async function PUT(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "PUT", `/credit-cards/${id}`, "update_credit_card");
}

export async function DELETE(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "DELETE", `/credit-cards/${id}`, "delete_credit_card");
}
