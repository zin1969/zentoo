import { apiFetch } from "@/lib/api/apiFetch";

export type SettlementJournalInput = {
  journal_date: string;
  // 立替金の口座
  receivable_account_id: number;
  // 立替金から減らす額
  settled_amount: number;
  // 受け取った額（全額おごりになったときは 0）
  received_amount: number;
  // 入金先の口座（受け取った額が 0 なら null）
  to_account_id: number | null;
  // 差額の科目（少なく受け取ったら費用科目、多く受け取ったら収益科目。差額が無ければ null）
  difference_account_id: number | null;
  // 空なら「精算 立替金の口座名」
  description: string;
};

export async function createSettlementJournal(input: SettlementJournalInput) {
  return apiFetch<{ journal_id: number }>("/settlement-journals", { method: "POST", body: input });
}

// 仕訳は作り直されるので、返る journal_id は新しい ID
export async function updateSettlementJournal(id: number, input: SettlementJournalInput) {
  return apiFetch<{ journal_id: number }>(`/settlement-journals/${id}`, { method: "PUT", body: input });
}
