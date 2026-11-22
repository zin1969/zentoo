import { apiFetch } from "@/lib/api/apiFetch";

export type IncomeJournalInput = {
  journal_date: string;
  // 入金先の口座（預金・現金・電子マネー）
  asset_account_id: number;
  revenue_account_id: number;
  amount: number;
  // 支払元など。空なら収益科目の名前が入る
  description: string;
};

export async function createIncomeJournal(input: IncomeJournalInput) {
  return apiFetch<{ journal_id: number }>("/income-journals", { method: "POST", body: input });
}

// 仕訳は作り直されるので、返る journal_id は新しい ID
export async function updateIncomeJournal(id: number, input: IncomeJournalInput) {
  return apiFetch<{ journal_id: number }>(`/income-journals/${id}`, { method: "PUT", body: input });
}
