import { apiFetch } from "@/lib/api/apiFetch";

export async function createOpeningAsset(body: unknown) {
  return apiFetch("/asset-opening-journals", {
    method: "POST",
    body: body
  });
}
