import { apiFetch } from "@/lib/api/apiFetch";

export async function createCashDeposit(body: unknown) {
  return apiFetch("/cash-deposit-journals", {
    method: "POST",
    body: body
  });
}
