import { apiFetch } from "@/lib/api/apiFetch";

export type ExpenseAccount = {
  id: number;
  name: string;
  // 親の科目の ID（トップレベルの科目は null）
  parent_id: number | null;
  // 仕訳で使われている。削除と親の付け替えができない
  in_use: boolean;
  // 子科目がある。削除できない
  has_children: boolean;
};

export type ExpenseAccountInput = {
  name: string;
  parent_id: number | null;
};

export async function getExpenseAccounts() {
  return apiFetch<ExpenseAccount[]>("/accounts/expense-accounts");
}

export async function createExpenseAccount(input: ExpenseAccountInput) {
  return apiFetch<{ id: number }>("/accounts/expense-accounts", { method: "POST", body: input });
}

export async function updateExpenseAccount(id: number, input: ExpenseAccountInput) {
  return apiFetch<{ id: number }>(`/accounts/expense-accounts/${id}`, { method: "PUT", body: input });
}

export async function deleteExpenseAccount(id: number) {
  await apiFetch<null>(`/accounts/expense-accounts/${id}`, { method: "DELETE" });
}
