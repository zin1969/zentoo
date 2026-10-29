import { apiFetch } from "@/lib/api/apiFetch";

export type MonthlyExpense = {
  account_id: number;
  account_name: string;
  amount: number;
};

export type MonthlyExpenses = {
  month: string;
  total: number;
  items: MonthlyExpense[];
};

// month は YYYY-MM。省略すると、Rails が今月（日本時間）で計算する
export async function getMonthlyExpenses(month?: string) {
  const query = month ? `?${new URLSearchParams({ month })}` : "";

  return apiFetch<MonthlyExpenses>(`/monthly-expenses${query}`);
}
