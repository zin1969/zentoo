import { apiFetch } from "@/lib/api/apiFetch";

export type AssetAccount = {
  id: number;
  name: string;
  element_type: number;
  payment_method_type: number;
};

export async function getAssetAccounts() {
  return apiFetch<AssetAccount[]>("/accounts/asset-accounts");
}
