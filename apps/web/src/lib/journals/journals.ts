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

export async function getJournal(id: number) {
  return apiFetch<Journal>(`/journals/${id}`);
}

const EXPENSE_ELEMENT_TYPE = 5;

// 修正できるのはお買い物の仕訳（借方がすべて費用）だけ。引き落とし仕訳は自動で作られたものなので直せない
export function isEditableJournal(journal: Journal) {
  return (
    !journal.original_journal_id &&
    journal.debits.length > 0 &&
    journal.debits.every((debit) => debit.element_type === EXPENSE_ELEMENT_TYPE)
  );
}

// カード払いの仕訳を削除すると、自動で作られた引き落とし仕訳も一緒に削除される
export async function deleteJournal(id: number) {
  await apiFetch<null>(`/journals/${id}`, { method: "DELETE" });
}
