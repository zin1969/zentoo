import { apiFetch } from "@/lib/api/apiFetch";

export type AccountBalance = {
  account_id: number;
  account_name: string;
  balance: number;
};

export type AccountBalances = {
  date: string;
  assets: AccountBalance[];
  liabilities: AccountBalance[];
  total_assets: number;
  total_liabilities: number;
  net_assets: number;
};

// date を省略すると、Rails が今日（日本時間）で計算する
export async function getAccountBalances(date?: string) {
  const query = date ? `?${new URLSearchParams({ date })}` : "";

  return apiFetch<AccountBalances>(`/account-balances${query}`);
}
