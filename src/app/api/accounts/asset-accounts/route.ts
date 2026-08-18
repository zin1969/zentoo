// src/app/api/accounts/asset-accounts/route.ts

import { apiFetch } from "@/lib/rails/apiFetch";

export async function GET() {
  const res = await apiFetch("/asset-accounts");
  return Response.json(await res.json());
}
