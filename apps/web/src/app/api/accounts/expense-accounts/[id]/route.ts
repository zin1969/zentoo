// src/app/api/accounts/expense-accounts/[id]/route.ts

import { isNumericId, proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

type Context = { params: Promise<{ id: string }> };

const NOT_FOUND = { error: "expense_account_not_found" };

export async function PUT(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "PUT", `/expense-accounts/${id}`, "update_expense_account");
}

export async function DELETE(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "DELETE", `/expense-accounts/${id}`, "delete_expense_account");
}
