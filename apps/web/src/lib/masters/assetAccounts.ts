import { apiFetch } from "@/lib/api/apiFetch";

export type AssetAccount = {
  id: number;
  name: string;
  element_type: number;
  // 口座の種別（1: 現金、2: 預金、3: 電子マネー）。支払い方法の種別と同じ値
  payment_method_type: number;
  // 仕訳で使われているか、カードの引き落とし口座になっている。削除と種別の変更ができない
  in_use: boolean;
};

export const ASSET_TYPES = [
  { value: 1, label: "現金" },
  { value: 2, label: "預金" },
  { value: 3, label: "電子マネー" }
] as const;

export type AssetAccountInput = {
  name: string;
  asset_type: number;
};

export async function getAssetAccounts() {
  return apiFetch<AssetAccount[]>("/accounts/asset-accounts");
}

export async function createAssetAccount(input: AssetAccountInput) {
  return apiFetch<{ id: number }>("/accounts/asset-accounts", { method: "POST", body: input });
}

export async function updateAssetAccount(id: number, input: AssetAccountInput) {
  return apiFetch<{ id: number }>(`/accounts/asset-accounts/${id}`, { method: "PUT", body: input });
}

export async function deleteAssetAccount(id: number) {
  await apiFetch<null>(`/accounts/asset-accounts/${id}`, { method: "DELETE" });
}
