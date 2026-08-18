import { apiFetch } from "@/lib/api/apiFetch";

export type AssetAccount = {
  id: number;
  name: string;
};

export async function getAssetAccounts() {
  return apiFetch<AssetAccount[]>("/accounts/asset-accounts");
}
