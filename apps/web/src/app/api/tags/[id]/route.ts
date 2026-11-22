// src/app/api/tags/[id]/route.ts

import { isNumericId, proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

type Context = { params: Promise<{ id: string }> };

const NOT_FOUND = { error: "tag_not_found" };

export async function PUT(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "PUT", `/tags/${id}`, "update_tag");
}

export async function DELETE(req: Request, { params }: Context) {
  const { id } = await params;
  if (!isNumericId(id)) return Response.json(NOT_FOUND, { status: 404 });

  return proxyAuthedWrite(req, "DELETE", `/tags/${id}`, "delete_tag");
}
