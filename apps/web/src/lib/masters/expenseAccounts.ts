import { twoLevelAccountsApi, type TwoLevelAccount } from "@/lib/masters/twoLevelAccounts";

export type ExpenseAccount = TwoLevelAccount;

export const expenseAccountsApi = twoLevelAccountsApi("/accounts/expense-accounts");

export async function getExpenseAccounts() {
  return expenseAccountsApi.list();
}
