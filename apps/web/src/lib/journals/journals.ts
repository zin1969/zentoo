import { apiFetch } from "@/lib/api/apiFetch";

export type JournalDebit = {
  element_type: number;
  account_id: number;
  account_name: string | null;
  // 資産の明細の口座の種別（6 = 立替金など）。資産以外の明細は null
  asset_type: number | null;
  item_name: string | null;
  amount: number;
  // 外税のレシートで登録した明細の税率（%）と税抜の金額。内税の明細は null。消費税は amount - tax_excluded_amount
  tax_rate: number | null;
  tax_excluded_amount: number | null;
  // 株の銘柄の株数（開始残高・買い）。それ以外の明細は null
  shares: number | null;
  // 明細に付いているタグ（お買い物の費用の明細だけ）
  tags: { id: number; name: string }[];
};

export type JournalCredit = {
  element_type: number;
  payment_method_type: number;
  account_id: number;
  account_name: string | null;
  amount: number;
  // 株の銘柄の株数（売り）。それ以外の明細は null
  shares: number | null;
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
  // 科目で絞り込んだときだけ、条件に合う仕訳全体（全ページ）での、その科目の借方合計・貸方合計
  account_totals: { debit_total: number; credit_total: number } | null;
};

// 条件はすべて AND。期間を省略すると全期間から探す
export type JournalQuery = {
  from?: string;
  to?: string;
  page?: number;
  // 店舗名（摘要）か明細の品目に含まれる文字列
  q?: string;
  // 借方・貸方のどちらかでこの科目を使っている仕訳（費用・収益科目は子科目も含む）
  account?: { element_type: number; account_id: number };
  // このタグが付いた明細のある仕訳
  tagId?: number;
};

export async function getJournals({ from, to, page, q, account, tagId }: JournalQuery = {}) {
  const params = new URLSearchParams();

  if (from) params.set("from", from);
  if (to) params.set("to", to);
  if (page && page > 1) params.set("page", String(page));
  if (q?.trim()) params.set("q", q.trim());
  if (account) {
    params.set("element_type", String(account.element_type));
    params.set("account_id", String(account.account_id));
  }
  if (tagId) params.set("tag_id", String(tagId));

  const query = params.toString();

  return apiFetch<JournalPage>(query ? `/journals?${query}` : "/journals");
}

export async function getJournal(id: number) {
  return apiFetch<Journal>(`/journals/${id}`);
}

const ASSET_ELEMENT_TYPE = 1;
const EXPENSE_ELEMENT_TYPE = 5;
const RECEIVABLE_ASSET_TYPE = 6;

function isReceivableDebit(debit: JournalDebit) {
  return debit.element_type === ASSET_ELEMENT_TYPE && debit.asset_type === RECEIVABLE_ASSET_TYPE && debit.shares === null;
}

// 精算の仕訳（貸方に立替金がある）。精算の画面で直す。立替金が貸方に来るのは精算だけ
export function isSettlementJournal(journal: Journal) {
  return journal.credits.some(
    (credit) => credit.element_type === ASSET_ELEMENT_TYPE && credit.payment_method_type === RECEIVABLE_ASSET_TYPE
  );
}

// お買い物の仕訳（借方がすべて費用か立替金）。お買い物の画面で直す。引き落とし仕訳は自動で作られたものなので直せない。
// 借方が立替金だけで振替の形のもの（PASMO → 立替金 会社）は、振替の画面で直す
export function isEditableJournal(journal: Journal) {
  return (
    !journal.original_journal_id &&
    !isSettlementJournal(journal) &&
    journal.debits.length > 0 &&
    journal.debits.every((debit) => debit.element_type === EXPENSE_ELEMENT_TYPE || isReceivableDebit(debit)) &&
    (journal.debits.some((debit) => debit.element_type === EXPENSE_ELEMENT_TYPE) || !isTransferJournal(journal))
  );
}

const REVENUE_ELEMENT_TYPE = 4;

// 収入の仕訳（貸方がすべて収益）。収入の修正画面で直す
export function isIncomeJournal(journal: Journal) {
  return (
    journal.credits.length > 0 && journal.credits.every((credit) => credit.element_type === REVENUE_ELEMENT_TYPE)
  );
}

const LIABILITY_ELEMENT_TYPE = 2;
const CREDIT_CARD_PAYMENT_METHOD_TYPE = 3;
const E_MONEY_ASSET_TYPE = 3;

// 振替の仕訳（借方が口座 1 つ、貸方が口座かクレジットカード 1 つ）。振替の修正画面で直す。
// 以前の「現金の預け入れ」もこの形。引き落とし仕訳（借方がカード）は含まれない。
// 株の買い（と損益の出ない売り）も同じ形になるが、株数を持つので振替ではない（直せない。削除して登録し直す）。
// 差額の無い精算も同じ形になるが、精算の画面で直す。カードから入れられるのは電子マネーだけ
// （カードで全額を立て替えたお買い物は、お買い物の画面で直す）
export function isTransferJournal(journal: Journal) {
  const [debit, ...otherDebits] = journal.debits;
  const [credit, ...otherCredits] = journal.credits;
  if (!debit || !credit || otherDebits.length > 0 || otherCredits.length > 0) return false;
  if (debit.shares !== null || credit.shares !== null) return false;
  if (isSettlementJournal(journal)) return false;

  return (
    debit.element_type === ASSET_ELEMENT_TYPE &&
    (credit.element_type === ASSET_ELEMENT_TYPE ||
      (credit.element_type === LIABILITY_ELEMENT_TYPE &&
        credit.payment_method_type === CREDIT_CARD_PAYMENT_METHOD_TYPE &&
        debit.asset_type === E_MONEY_ASSET_TYPE))
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
