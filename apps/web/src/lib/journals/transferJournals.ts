import { apiFetch } from "@/lib/api/apiFetch";

export type TransferJournalInput = {
  journal_date: string;
  // 出す元: 口座（"asset"）か、クレジットカード（"credit_card"。電子マネーへのチャージだけ）
  from_type: "asset" | "credit_card";
  from_account_id: number;
  // 入れる先の口座
  to_account_id: number;
  amount: number;
  // 空なら組み合わせから決まる（引き出し・預入・チャージ・振替）
  description: string;
};

export async function createTransferJournal(input: TransferJournalInput) {
  return apiFetch<{ journal_id: number }>("/transfer-journals", { method: "POST", body: input });
}

// 仕訳は作り直されるので、返る journal_id は新しい ID
export async function updateTransferJournal(id: number, input: TransferJournalInput) {
  return apiFetch<{ journal_id: number }>(`/transfer-journals/${id}`, { method: "PUT", body: input });
}
