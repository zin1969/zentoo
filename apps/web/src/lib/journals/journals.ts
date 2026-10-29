import { apiFetch } from "@/lib/api/apiFetch";

export type JournalDebit = {
  element_type: number;
  account_id: number;
  account_name: string | null;
  item_name: string | null;
  amount: number;
};

export type JournalCredit = {
  element_type: number;
  payment_method_type: number;
  account_id: number;
  account_name: string | null;
  amount: number;
};

export type Journal = {
  id: number;
  journal_date: string;
  store_name: string | null;
  debits: JournalDebit[];
  credits: JournalCredit[];
  // この仕訳が引き落とし仕訳の場合、元のカード払い仕訳の ID
  original_journal_id: number | null;
  // この仕訳がカード払いの場合、引き落とし仕訳の ID
  direct_debit_journal_id: number | null;
};

export type JournalPage = {
  journals: Journal[];
  page: number;
  per_page: number;
  total_count: number;
};

export type JournalQuery = {
  from?: string;
  to?: string;
  page?: number;
};

export async function getJournals({ from, to, page }: JournalQuery = {}) {
  const params = new URLSearchParams();

  if (from) params.set("from", from);
  if (to) params.set("to", to);
  if (page && page > 1) params.set("page", String(page));

  const query = params.toString();

  return apiFetch<JournalPage>(query ? `/journals?${query}` : "/journals");
}
