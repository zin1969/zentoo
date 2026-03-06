import { apiFetch } from "@/lib/api/apiFetch";

export async function createOpeningAsset(body: any) {
  return apiFetch("/asset-opening-journals", {
    method: "POST",
    body: JSON.stringify(body)
  });
}
