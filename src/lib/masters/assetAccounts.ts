import { apiFetch } from "@/lib/api/apiFetch";

export async function getAssetAccounts() {
  return apiFetch("/accounts/asset-accounts");
}
