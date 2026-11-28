import { apiFetch } from "@/lib/api/apiFetch";

// 対象: 1 = 費用科目（子科目も含む）、2 = タグ
export const TARGET_EXPENSE_ACCOUNT = 1;
export const TARGET_TAG = 2;

// 周期: 1 = 週（月曜〜日曜）、2 = 月、3 = 年（1 月〜12 月）
export const PERIOD_WEEK = 1;
export const PERIOD_MONTH = 2;
export const PERIOD_YEAR = 3;

export const PERIODS = [
  { value: PERIOD_WEEK, label: "週", current: "今週" },
  { value: PERIOD_MONTH, label: "月", current: "今月" },
  { value: PERIOD_YEAR, label: "年", current: "今年" }
] as const;

export type Budget = {
  id: number;
  name: string;
  target_type: number;
  expense_account_id: number | null;
  tag_id: number | null;
  // 対象の科目かタグの名前
  target_name: string | null;
  period_type: number;
  amount: number;
  // 1〜12 月で月ごとに決めた額（月の予算だけ）。毎月同じ額なら null
  monthly_amounts: number[] | null;
  // 科目の予算から外すタグ
  excluded_tags: { id: number; name: string }[];
};

export type BudgetInput = {
  name: string;
  target_type: number;
  expense_account_id: number | null;
  tag_id: number | null;
  period_type: number;
  amount: number;
  monthly_amounts: number[] | null;
  excluded_tag_ids: number[];
};

export type BudgetReportItem = Budget & {
  period_start: string;
  period_end: string;
  // その期間の予算額（月ごとに決めた額なら、その月の額）
  budget_amount: number;
  used_amount: number;
  remaining_amount: number;
};

export type BudgetReport = {
  date: string;
  budgets: BudgetReportItem[];
};

export async function getBudgets() {
  return apiFetch<Budget[]>("/budgets");
}

export async function createBudget(input: BudgetInput) {
  return apiFetch<{ id: number }>("/budgets", { method: "POST", body: input });
}

export async function updateBudget(id: number, input: BudgetInput) {
  return apiFetch<{ id: number }>(`/budgets/${id}`, { method: "PUT", body: input });
}

export async function deleteBudget(id: number) {
  await apiFetch<null>(`/budgets/${id}`, { method: "DELETE" });
}

// date を含む期間（予算ごとに週・月・年）の予算額と使った額。date を省略すると今日（日本時間）
export async function getBudgetReport(date?: string) {
  const query = date ? `?${new URLSearchParams({ date })}` : "";

  return apiFetch<BudgetReport>(`/budget-reports${query}`);
}
