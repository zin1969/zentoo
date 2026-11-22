import { apiFetch } from "@/lib/api/apiFetch";

export type JournalDebit = {
  element_type: number;
  account_id: number;
  account_name: string | null;
  item_name: string | null;
  amount: number;
  // 明細に付いているタグ（お買い物の費用の明細だけ）
  tags: { id: number; name: string }[];
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
  // 引き落とし仕訳の日付を手で変えたか（引き落とし仕訳以外は false）
  payment_date_overridden: boolean;
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

const REVENUE_ELEMENT_TYPE = 4;

// 収入の仕訳（貸方がすべて収益）。収入の修正画面で直す
export function isIncomeJournal(journal: Journal) {
  return (
    journal.credits.length > 0 && journal.credits.every((credit) => credit.element_type === REVENUE_ELEMENT_TYPE)
  );
}

const ASSET_ELEMENT_TYPE = 1;
const LIABILITY_ELEMENT_TYPE = 2;
const CREDIT_CARD_PAYMENT_METHOD_TYPE = 3;

// 振替の仕訳（借方が口座 1 つ、貸方が口座かクレジットカード 1 つ）。振替の修正画面で直す。
// 以前の「現金の預け入れ」もこの形。引き落とし仕訳（借方がカード）は含まれない
export function isTransferJournal(journal: Journal) {
  const [debit, ...otherDebits] = journal.debits;
  const [credit, ...otherCredits] = journal.credits;
  if (!debit || !credit || otherDebits.length > 0 || otherCredits.length > 0) return false;

  return (
    debit.element_type === ASSET_ELEMENT_TYPE &&
    (credit.element_type === ASSET_ELEMENT_TYPE ||
      (credit.element_type === LIABILITY_ELEMENT_TYPE && credit.payment_method_type === CREDIT_CARD_PAYMENT_METHOD_TYPE))
  );
}

// カード払いの仕訳を削除すると、自動で作られた引き落とし仕訳も一緒に削除される
export async function deleteJournal(id: number) {
  await apiFetch<null>(`/journals/${id}`, { method: "DELETE" });
}

// カード払いの引き落とし仕訳の日付だけを変える。id は引き落とし仕訳の ID
export async function updateDirectDebitDate(id: number, paymentDate: string) {
  await apiFetch<{ journal_id: number }>(`/direct-debit-journals/${id}`, {
    method: "PUT",
    body: { payment_date: paymentDate }
  });
}
