import { apiFetch } from "@/lib/api/apiFetch";

export type LedgerItem = {
  journal_id: number;
  journal_date: string;
  store_name: string | null;
  // そのカードで払った額
  amount: number;
};

export type LedgerEntry = {
  // carried_over: 繰越（1 行目）、journal: 1 つの仕訳、card_payment: 同じ日・同じカードの引き落としのまとめ
  row_type: "carried_over" | "journal" | "card_payment";
  date: string;
  description: string | null;
  deposit: number;
  withdrawal: number;
  balance: number;
  // 今日より後の、まだ引き落とされていない予定
  scheduled: boolean;
  card_account_id: number | null;
  journal_ids: number[];
  // カードの行の、元のお買い物の内訳
  items: LedgerItem[];
};

export type BankAccountLedger = {
  account: { id: number; name: string };
  from: string;
  to: string;
  today: string;
  entries: LedgerEntry[];
};

// from・to を省略すると、Rails が既定の期間（先月の初め〜最後の予定日）で返す
export async function getBankAccountLedger(accountId: number, { from, to }: { from?: string; to?: string } = {}) {
  const params = new URLSearchParams();

  if (from) params.set("from", from);
  if (to) params.set("to", to);

  const query = params.toString();

  return apiFetch<BankAccountLedger>(`/bank-account-ledgers/${accountId}${query ? `?${query}` : ""}`);
}
