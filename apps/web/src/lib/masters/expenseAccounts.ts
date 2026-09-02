import { apiFetch } from "@/lib/api/apiFetch";

export type ExpenseAccount = {
  id: number;
  name: string;
};

export async function getExpenseAccounts() {
  return apiFetch<ExpenseAccount[]>("/accounts/expense-accounts");
}
