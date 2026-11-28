import { apiFetch } from "@/lib/api/apiFetch";

export type AssetAccount = {
  id: number;
  name: string;
  element_type: number;
  // 口座の種別（1: 現金、2: 預金、3: 電子マネー、4: 証券口座、5: 投資、6: 立替金）。支払い方法の種別と同じ値
  payment_method_type: number;
  // 仕訳で使われているか、カードの引き落とし口座になっている。削除と種別の変更ができない
  in_use: boolean;
};

export const ASSET_TYPES = [
  { value: 1, label: "現金" },
  { value: 2, label: "預金" },
  { value: 3, label: "電子マネー" },
  { value: 4, label: "証券口座（預り金）" },
  { value: 5, label: "投資（iDeCo・NISA・株式など）" },
  { value: 6, label: "立替金（立て替えた相手ごと）" }
] as const;

// 立替金。お買い物で立て替えた分・振替で入れた分を残し、返してもらったら精算の画面で登録する
export const RECEIVABLE_ASSET_TYPE = 6;

// お金の出し入れに使う口座の種別（立替金を除く）。立替金から出すのは精算だけ
export const NON_RECEIVABLE_ASSET_TYPES = ASSET_TYPES.filter((type) => type.value !== RECEIVABLE_ASSET_TYPE);

// 支払いに使える口座の種別（現金・預金・電子マネー）。証券口座・投資は振替と収入でだけ使う
export const PAYMENT_ASSET_TYPES = ASSET_TYPES.filter((type) => type.value <= 3);

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
