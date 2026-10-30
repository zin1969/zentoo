import { apiFetch } from "@/lib/api/apiFetch";

export async function createOpeningLiability(body: unknown) {
  return apiFetch("/liability-opening-journals", {
    method: "POST",
    body: body
  });
}
