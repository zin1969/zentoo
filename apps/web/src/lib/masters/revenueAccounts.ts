import { twoLevelAccountsApi, type TwoLevelAccount } from "@/lib/masters/twoLevelAccounts";

export type RevenueAccount = TwoLevelAccount;

export const revenueAccountsApi = twoLevelAccountsApi("/accounts/revenue-accounts");

export async function getRevenueAccounts() {
  return revenueAccountsApi.list();
}
