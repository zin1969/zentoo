"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createJournalEntry } from "../actions/createJournalEntry";
import { updateJournalEntry } from "../actions/updateJournalEntry";
import { ExpenseAccount, getExpenseAccounts } from "@/lib/masters/expenseAccounts";
import { getAssetAccounts } from "@/lib/masters/assetAccounts";
import { getLiabilityAccounts } from "@/lib/masters/liabilityAccounts";
import { ApiError, type ApiErrorBody } from "@/lib/api/apiFetch";
import type { Journal } from "@/lib/journals/journals";
import { createTag, getTags, type Tag } from "@/lib/masters/tags";
import { calculateTax, defaultTax } from "@/lib/journals/consumptionTax";
import { localToday } from "@/lib/dates/localToday";

type Status = "idle" | "submitting" | "success" | "error";

const EXPENSE_ELEMENT_TYPE = 5;
const MAX_TAG_NAME_LENGTH = 30;
const MAX_TAX_RATE = 100;
// 外税のときに選べる税率。一時的な税率などは「その他」で数値を入れる
const TAX_RATE_CHOICES = ["10", "8"];

// 税込: 明細の金額は税込（今まで通り）。税抜: 外税のレシートで、明細の金額は税抜
type TaxMode = "included" | "excluded";

type DebitLine = {
  key: string;
  itemName: string;
  // タグの名前（任意）。当面は明細ごとに 1 つ。無い名前は、登録の前にその場で作る
  tagName: string;
  // 選んだ親の科目。空なら、選んだ科目（expenseAccountId）からたどる（修正で開いたとき）
  parentId: string;
  // 登録する科目。子科目か、親の科目そのもの（「〇〇のまま」）
  expenseAccountId: string;
  // 税込のときは税込の金額、税抜（外税）のときは税抜の金額
  amount: string;
  // 税抜（外税）のときの税率。「10」「8」か「other」（customRate に数値を入れる）
  rateChoice: string;
  customRate: string;
};

type CreditLine = {
  key: string;
  // 資産と負債は別テーブルで ID が重なるため、「種別-ID」で区別する（paymentKey 参照）
  paymentKey: string;
  amount: string;
};

type PaymentAccount = {
  id: number;
  name: string;
  element_type: number;
  payment_method_type: number;
  category: "asset" | "liability";
};

const DEPOSIT_PAYMENT_METHOD_TYPE = 2;
const ASSET_ELEMENT_TYPE = 1;

function paymentKey(account: Pick<PaymentAccount, "category" | "id">) {
  return `${account.category}-${account.id}`;
}

let lineKeySeq = 0;
function nextKey() {
  lineKeySeq += 1;
  return `line-${lineKeySeq}`;
}

function emptyDebitLine(): DebitLine {
  return {
    key: nextKey(),
    itemName: "",
    tagName: "",
    parentId: "",
    expenseAccountId: "",
    amount: "",
    rateChoice: TAX_RATE_CHOICES[0],
    customRate: ""
  };
}

function emptyCreditLine(): CreditLine {
  return { key: nextKey(), paymentKey: "", amount: "" };
}

// 修正のときは、元の仕訳の内容をフォームの初期値にする。外税で登録した明細は、税抜の金額と税率で開く
function debitLinesFrom(journal: Journal): DebitLine[] {
  return journal.debits.map((debit) => {
    const rate = debit.tax_rate === null ? null : String(debit.tax_rate);
    const isChoice = rate !== null && TAX_RATE_CHOICES.includes(rate);

    return {
      key: nextKey(),
      itemName: debit.item_name ?? "",
      tagName: debit.tags[0]?.name ?? "",
      parentId: "",
      expenseAccountId: String(debit.account_id),
      amount: String(debit.tax_excluded_amount ?? debit.amount),
      rateChoice: rate === null ? TAX_RATE_CHOICES[0] : isChoice ? rate : "other",
      customRate: rate !== null && !isChoice ? rate : ""
    };
  });
}

function isExcludedJournal(journal?: Journal) {
  return journal?.debits.some((debit) => debit.tax_rate !== null) ?? false;
}

// 修正のときに、登録したときの税率ごとの消費税を再現する（自動の計算と違えば、手で直した値として開く）
function taxOverridesFrom(journal?: Journal): Record<string, string> {
  if (!isExcludedJournal(journal)) return {};

  const groups = new Map<number, { subtotal: number; tax: number }>();
  for (const debit of journal?.debits ?? []) {
    if (debit.tax_rate === null || debit.tax_excluded_amount === null) continue;

    const group = groups.get(debit.tax_rate) ?? { subtotal: 0, tax: 0 };
    group.subtotal += debit.tax_excluded_amount;
    group.tax += debit.amount - debit.tax_excluded_amount;
    groups.set(debit.tax_rate, group);
  }

  return Object.fromEntries(
    [...groups].flatMap(([rate, group]) =>
      group.tax === defaultTax(group.subtotal, rate) ? [] : [[String(rate), String(group.tax)]]
    )
  );
}

// 明細の税率。数値になっていなければ null
function lineTaxRate(line: DebitLine): number | null {
  const raw = line.rateChoice === "other" ? line.customRate.trim() : line.rateChoice;
  if (!/^\d+$/.test(raw)) return null;

  const rate = Number(raw);
  return rate <= MAX_TAX_RATE ? rate : null;
}

function creditLinesFrom(journal: Journal): CreditLine[] {
  return journal.credits.map((credit) => ({
    key: nextKey(),
    paymentKey: paymentKey({
      category: credit.element_type === ASSET_ELEMENT_TYPE ? "asset" : "liability",
      id: credit.account_id
    }),
    amount: String(credit.amount)
  }));
}

// 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する。
function isUnauthorized(error: unknown): boolean {
  return error instanceof ApiError && error.status === 401;
}

function sumAmounts(amounts: string[]) {
  return amounts.reduce((total, a) => total + (Number(a) || 0), 0);
}

function extractErrorMessage(error: unknown, isEdit: boolean): string {
  if (error instanceof ApiError) {
    const data: ApiErrorBody = error.data ?? {};

    if (Array.isArray(data?.errors) && data.errors.length > 0) {
      return data.errors.join(" / ");
    }

    if (data?.error === "unbalanced_journal") {
      return "貸方と借方の合計金額が一致していません。";
    }

    if (typeof data?.message === "string") {
      return data.message;
    }

    if (data?.error === "account_not_found") {
      return "選択した勘定科目が見つかりません。画面を再読み込みしてください。";
    }

    if (data?.error === "tag_not_found") {
      return "タグが見つかりません。画面を再読み込みしてください。";
    }

    if (data?.error === "tax_only_for_expense_debits") {
      return "税率は費用の明細にだけ付けられます。";
    }

    if (data?.error === "credit_card_setting_not_found") {
      return "クレジットカードの引き落とし設定が見つかりません。";
    }

    if (data?.error === "journal_not_found") {
      return "修正する仕訳が見つかりません。すでに削除されている可能性があります。";
    }

    if (
      data?.error === "journal_not_editable" ||
      data?.error === "direct_debit_journal_not_editable" ||
      data?.error === "expense_debits_required"
    ) {
      return "この仕訳は修正できません。削除して登録し直してください。";
    }
  }

  return isEdit
    ? "修正に失敗しました。時間をおいて再度お試しください。"
    : "登録に失敗しました。時間をおいて再度お試しください。";
}

type JournalEntryFormProps = {
  // 渡されたときは修正。元の仕訳の内容で開き、送信すると作り直して仕訳一覧に戻る
  journal?: Journal;
  // true のときは、journal の内容をコピーした新しい登録（日付は今日。元の仕訳は変えない）
  copy?: boolean;
};

export default function JournalEntryForm({ journal, copy = false }: JournalEntryFormProps = {}) {
  const isEdit = journal !== undefined && !copy;
  const router = useRouter();
  const [date, setDate] = useState(copy ? localToday() : (journal?.journal_date ?? ""));
  const [storeName, setStoreName] = useState(journal?.store_name ?? "");
  const [taxMode, setTaxMode] = useState<TaxMode>(isExcludedJournal(journal) ? "excluded" : "included");
  // 税率ごとに手で直した消費税（キーは税率）。空の税率は自動の計算を使う
  // コピーのときは、手で直した消費税は引き継がない（今の金額で計算し直す）
  const [taxOverrides, setTaxOverrides] = useState<Record<string, string>>(() =>
    copy ? {} : taxOverridesFrom(journal)
  );
  const [debitLines, setDebitLines] = useState<DebitLine[]>(() =>
    journal ? debitLinesFrom(journal) : [emptyDebitLine()]
  );
  const [creditLines, setCreditLines] = useState<CreditLine[]>(() =>
    journal ? creditLinesFrom(journal) : [emptyCreditLine()]
  );

  const [expenseAccounts, setExpenseAccounts] = useState<ExpenseAccount[]>([]);
  const [tags, setTags] = useState<Tag[]>([]);
  const [paymentAccounts, setPaymentAccounts] = useState<PaymentAccount[]>([]);

  const [status, setStatus] = useState<Status>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    const handleMasterError = (message: string) => (error: unknown) => {
      if (isUnauthorized(error)) {
        router.replace("/login");
        return;
      }

      setErrorMessage(message);
    };

    getTags()
      .then(setTags)
      .catch(handleMasterError("タグの取得に失敗しました。時間をおいて再度お試しください。"));

    getExpenseAccounts()
      .then(setExpenseAccounts)
      .catch(handleMasterError("勘定科目の取得に失敗しました。時間をおいて再度お試しください。"));

    Promise.all([getAssetAccounts(), getLiabilityAccounts()])
      .then(([assetAccounts, liabilityAccounts]) => {
        setPaymentAccounts([
          // 預貯金（銀行口座）は支払い方法として選ばせない。カード払いの引き落としは自動仕訳で作る
          ...assetAccounts
            .filter((a) => a.payment_method_type !== DEPOSIT_PAYMENT_METHOD_TYPE)
            .map((a) => ({ ...a, category: "asset" as const })),
          ...liabilityAccounts.map((a) => ({ ...a, category: "liability" as const }))
        ]);
      })
      .catch(handleMasterError("支払い方法の取得に失敗しました。時間をおいて再度お試しください。"));
  }, [router]);

  const isExcluded = taxMode === "excluded";

  // 税抜（外税）のとき: 税率ごとに消費税を計算して、明細を税込の金額にする
  const taxResult = calculateTax(
    debitLines.flatMap((line) => {
      const rate = lineTaxRate(line);
      return rate === null ? [] : [{ key: line.key, taxExcludedAmount: Number(line.amount) || 0, taxRate: rate }];
    }),
    new Map(
      Object.entries(taxOverrides).flatMap(([rate, value]) =>
        /^\d+$/.test(value.trim()) ? [[Number(rate), Number(value)] as [number, number]] : []
      )
    )
  );
  // 税率がすべて数値で、手で直した消費税も数値になっていること（空のままでは登録しない）
  const ratesValid =
    !isExcluded ||
    (debitLines.every((line) => lineTaxRate(line) !== null) &&
      taxResult.groups.every((group) => {
        const value = taxOverrides[String(group.rate)];
        return value === undefined || /^\d+$/.test(value.trim());
      }));

  const debitTotal = isExcluded ? taxResult.total : sumAmounts(debitLines.map((l) => l.amount));
  // 外税で支払い方法が 1 つなら、その金額は税込の合計で埋める（自分で計算しなくて済むように）
  const autoCreditAmount = isExcluded && creditLines.length === 1;
  const creditAmountOf = (line: CreditLine) => (autoCreditAmount ? debitTotal : Number(line.amount) || 0);
  const creditTotal = creditLines.reduce((total, line) => total + creditAmountOf(line), 0);
  const isBalanced = debitTotal > 0 && debitTotal === creditTotal && ratesValid;

  // 親の科目を選んでから、その子科目を選ぶ。親に子科目が無ければ、親の科目で登録する
  const hasAccount = (id: number | null) => id !== null && expenseAccounts.some((a) => a.id === id);
  const topLevelExpenseAccounts = expenseAccounts.filter((a) => !hasAccount(a.parent_id));
  const childrenOf = (parentId: string) => expenseAccounts.filter((a) => String(a.parent_id) === parentId);

  const parentIdOf = (line: DebitLine) => {
    if (line.parentId) return line.parentId;

    const account = expenseAccounts.find((a) => String(a.id) === line.expenseAccountId);
    if (!account) return "";

    return String(hasAccount(account.parent_id) ? account.parent_id : account.id);
  };

  const selectParent = (key: string, parentId: string) => {
    // 子科目があれば、子科目か「〇〇のまま」を選び直してもらう
    updateDebitLine(key, { parentId, expenseAccountId: childrenOf(parentId).length > 0 ? "" : parentId });
  };

  // 税率ごとの消費税を手で直す。自動の計算と同じ値なら、自動の計算に戻す
  const setTaxOverride = (rate: number, value: string, calculated: number) => {
    setTaxOverrides((current) => {
      const next = { ...current };
      if (value === String(calculated)) {
        delete next[String(rate)];
      } else {
        next[String(rate)] = value;
      }
      return next;
    });
  };

  const changeTaxMode = (mode: TaxMode) => {
    setTaxMode(mode);
    setTaxOverrides({});
  };

  const updateDebitLine = (key: string, patch: Partial<DebitLine>) => {
    setDebitLines((lines) => lines.map((l) => (l.key === key ? { ...l, ...patch } : l)));
  };

  const updateCreditLine = (key: string, patch: Partial<CreditLine>) => {
    setCreditLines((lines) => lines.map((l) => (l.key === key ? { ...l, ...patch } : l)));
  };

  const removeDebitLine = (key: string) => {
    setDebitLines((lines) => (lines.length > 1 ? lines.filter((l) => l.key !== key) : lines));
  };

  const removeCreditLine = (key: string) => {
    setCreditLines((lines) => (lines.length > 1 ? lines.filter((l) => l.key !== key) : lines));
  };

  // タグの名前を ID にする。無い名前は、お買い物を登録する前にその場で作る
  const resolveTagIds = async () => {
    const ids = new Map(tags.map((tag) => [tag.name, tag.id]));
    const names = new Set(debitLines.map((line) => line.tagName.trim()).filter((name) => name !== ""));

    for (const name of names) {
      if (ids.has(name)) continue;

      try {
        const created = await createTag(name);
        ids.set(name, created.id);
        setTags((current) => [...current, { id: created.id, name: created.name, usage_count: 0 }]);
      } catch (error) {
        // 別の画面で同じ名前のタグが作られていたら、それを使う
        if (!(error instanceof ApiError && error.data?.error === "duplicate_tag_name")) throw error;

        const latest = await getTags();
        setTags(latest);
        const existing = latest.find((tag) => tag.name === name);
        if (!existing) throw error;
        ids.set(name, existing.id);
      }
    }

    return ids;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setErrorMessage(null);

    try {
      const tagIds = await resolveTagIds();
      const body = {
        date,
        store_name: storeName,
        debits: debitLines.map((line) => ({
          element_type: EXPENSE_ELEMENT_TYPE,
          account_id: Number(line.expenseAccountId),
          // 金額はいつも税込。外税のときは、税率と税抜の金額も一緒に送る（修正のときの表示に使う）
          amount: isExcluded ? taxResult.amounts.get(line.key) : Number(line.amount),
          item_name: line.itemName,
          tag_ids: line.tagName.trim() ? [tagIds.get(line.tagName.trim())] : [],
          ...(isExcluded ? { tax_rate: lineTaxRate(line), tax_excluded_amount: Number(line.amount) } : {})
        })),
        credits: creditLines.map((line) => {
          const account = paymentAccounts.find((a) => paymentKey(a) === line.paymentKey);

          return {
            element_type: account?.element_type,
            payment_method_type: account?.payment_method_type,
            account_id: account?.id,
            amount: creditAmountOf(line)
          };
        })
      };

      if (isEdit && journal) {
        await updateJournalEntry(journal.id, body);
        router.push("/journals");
        return;
      }

      await createJournalEntry(body);

      setStatus("success");
      setDate("");
      setStoreName("");
      setDebitLines([emptyDebitLine()]);
      setCreditLines([emptyCreditLine()]);
      setTaxOverrides({});
    } catch (error) {
      if (isUnauthorized(error)) {
        router.replace("/login");
        return;
      }

      setStatus("error");
      setErrorMessage(extractErrorMessage(error, isEdit));
    }
  };

  const isSubmitting = status === "submitting";
  const actionLabel = isEdit ? "修正" : "登録";
  const submitLabel = isSubmitting ? `${actionLabel}中...` : actionLabel;
  const inputClass =
    "rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";
  const lineInputClass =
    "rounded-md border border-black/15 px-2.5 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";

  return (
    <form
      onSubmit={handleSubmit}
      className="flex w-full flex-col gap-5 rounded-xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-black/20"
    >
      {status === "success" && (
        <p className="rounded-md bg-green-50 px-3 py-2 text-sm text-green-700 dark:bg-green-900/30 dark:text-green-300">
          登録しました。
        </p>
      )}

      {errorMessage && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {errorMessage}
        </p>
      )}

      <div className="flex flex-col gap-1.5">
        <label htmlFor="journal-date" className="text-sm font-medium text-foreground">
          日付
        </label>
        <input
          id="journal-date"
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="store-name" className="text-sm font-medium text-foreground">
          店舗名
        </label>
        <input
          id="store-name"
          type="text"
          value={storeName}
          onChange={(e) => setStoreName(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      {/* 外税のレシートは、税抜の金額と税率を入れれば、消費税を計算して税込で登録する */}
      <div className="flex flex-col gap-1.5">
        <span className="text-sm font-medium text-foreground">レシートの金額</span>
        <div className="grid grid-cols-2 gap-1 rounded-lg bg-black/5 p-1 dark:bg-white/10" role="radiogroup">
          {(
            [
              ["included", "税込（内税）"],
              ["excluded", "税抜（外税）"]
            ] as const
          ).map(([mode, label]) => (
            <button
              key={mode}
              type="button"
              role="radio"
              aria-checked={taxMode === mode}
              onClick={() => changeTaxMode(mode)}
              className={
                taxMode === mode
                  ? "rounded-md bg-white px-3 py-1.5 text-sm font-medium text-foreground shadow-sm dark:bg-black/40"
                  : "rounded-md px-3 py-1.5 text-sm text-black/60 dark:text-white/60"
              }
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      <div className="flex flex-col gap-2.5">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-foreground">明細</span>
          <button
            type="button"
            onClick={() => setDebitLines((lines) => [...lines, emptyDebitLine()])}
            className="text-sm font-medium text-blue-600 hover:text-blue-700"
          >
            + 明細を追加
          </button>
        </div>

        <div className="flex flex-col gap-2">
          {debitLines.map((line) => (
            <div
              key={line.key}
              className="flex flex-col gap-2 rounded-lg border border-black/10 p-3 dark:border-white/10"
            >
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  placeholder="品目名"
                  value={line.itemName}
                  onChange={(e) => updateDebitLine(line.key, { itemName: e.target.value })}
                  required
                  className={`${lineInputClass} min-w-0 flex-1`}
                />
                <button
                  type="button"
                  onClick={() => removeDebitLine(line.key)}
                  disabled={debitLines.length === 1}
                  aria-label="この明細を削除"
                  className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-black/35 hover:text-red-600 disabled:cursor-not-allowed disabled:opacity-30 dark:text-white/35"
                >
                  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                    <path
                      d="M3.5 4.5h9M6.5 4.5V3a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1v1.5M4.5 4.5l.6 8a1 1 0 0 0 1 .9h3.8a1 1 0 0 0 1-.9l.6-8"
                      stroke="currentColor"
                      strokeWidth="1.3"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                </button>
              </div>
              <div className="flex items-center gap-2">
                <select
                  aria-label="勘定科目"
                  value={parentIdOf(line)}
                  onChange={(e) => selectParent(line.key, e.target.value)}
                  required
                  className={`${lineInputClass} min-w-0 flex-1`}
                >
                  <option value="">勘定科目を選択</option>
                  {topLevelExpenseAccounts.map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.name}
                    </option>
                  ))}
                </select>
                <div className="relative w-28 shrink-0">
                  <span className="pointer-events-none absolute inset-y-0 left-2.5 flex items-center text-sm text-black/40 dark:text-white/40">
                    ¥
                  </span>
                  <input
                    type="number"
                    min="1"
                    aria-label={isExcluded ? "税抜の金額" : "金額"}
                    placeholder={isExcluded ? "税抜" : ""}
                    value={line.amount}
                    onChange={(e) => updateDebitLine(line.key, { amount: e.target.value })}
                    required
                    className={`${lineInputClass} w-full pl-6 text-right`}
                  />
                </div>
              </div>
              {childrenOf(parentIdOf(line)).length > 0 && (
                <select
                  aria-label="子科目"
                  value={line.expenseAccountId}
                  onChange={(e) => updateDebitLine(line.key, { expenseAccountId: e.target.value })}
                  required
                  className={`${lineInputClass} min-w-0`}
                >
                  <option value="">子科目を選択</option>
                  {/* 合う子科目が無いときに、登録を中断して科目を足さなくて済むよう、親のままでも登録できる */}
                  <option value={parentIdOf(line)}>
                    （{expenseAccounts.find((a) => String(a.id) === parentIdOf(line))?.name}のまま）
                  </option>
                  {childrenOf(parentIdOf(line)).map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.name}
                    </option>
                  ))}
                </select>
              )}
              {isExcluded && (
                <div className="flex items-center gap-2">
                  <select
                    aria-label="税率"
                    value={line.rateChoice}
                    onChange={(e) => updateDebitLine(line.key, { rateChoice: e.target.value })}
                    className={`${lineInputClass} w-24 shrink-0`}
                  >
                    {TAX_RATE_CHOICES.map((rate) => (
                      <option key={rate} value={rate}>
                        {rate}%
                      </option>
                    ))}
                    <option value="other">その他</option>
                  </select>
                  {line.rateChoice === "other" && (
                    <div className="relative w-20 shrink-0">
                      <input
                        type="number"
                        min="0"
                        max={MAX_TAX_RATE}
                        aria-label="税率（%）"
                        value={line.customRate}
                        onChange={(e) => updateDebitLine(line.key, { customRate: e.target.value })}
                        required
                        className={`${lineInputClass} w-full pr-6 text-right`}
                      />
                      <span className="pointer-events-none absolute inset-y-0 right-2.5 flex items-center text-sm text-black/40 dark:text-white/40">
                        %
                      </span>
                    </div>
                  )}
                  <span className="ml-auto text-xs tabular-nums text-black/55 dark:text-white/55">
                    税込 ¥{(taxResult.amounts.get(line.key) ?? 0).toLocaleString()}
                  </span>
                </div>
              )}
              {/* 何のために使ったか。候補に無い名前は、登録のときに新しいタグとして作る */}
              <input
                type="text"
                aria-label="タグ"
                placeholder="タグ（任意。勉強・娯楽など）"
                list="journal-entry-tags"
                value={line.tagName}
                maxLength={MAX_TAG_NAME_LENGTH}
                onChange={(e) => updateDebitLine(line.key, { tagName: e.target.value })}
                className={`${lineInputClass} min-w-0`}
              />
            </div>
          ))}
          <datalist id="journal-entry-tags">
            {tags.map((tag) => (
              <option key={tag.id} value={tag.name} />
            ))}
          </datalist>
        </div>

        {isExcluded && taxResult.groups.length > 0 && (
          <div className="flex flex-col gap-1.5 rounded-lg bg-black/5 p-3 text-sm dark:bg-white/5">
            {taxResult.groups.map((group) => (
              <div key={group.rate} className="flex items-center justify-between gap-2">
                <span className="text-black/60 dark:text-white/60">
                  {group.rate}% 対象 ¥{group.subtotal.toLocaleString()}
                </span>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs text-black/55 dark:text-white/55">消費税</span>
                  <div className="relative w-24">
                    <span className="pointer-events-none absolute inset-y-0 left-2.5 flex items-center text-sm text-black/40 dark:text-white/40">
                      ¥
                    </span>
                    <input
                      type="number"
                      min="0"
                      aria-label={`${group.rate}% の消費税`}
                      value={taxOverrides[String(group.rate)] ?? String(group.defaultTax)}
                      onChange={(e) => setTaxOverride(group.rate, e.target.value, group.defaultTax)}
                      className={`${lineInputClass} w-full pl-6 text-right`}
                    />
                  </div>
                </div>
              </div>
            ))}
            <p className="text-xs text-black/50 dark:text-white/50">
              消費税は税率ごとの合計から計算しています（端数は切り捨て）。レシートと違うときは直してください。
            </p>
          </div>
        )}

        <div className="flex items-baseline justify-between pt-0.5">
          <span className="text-sm text-black/55 dark:text-white/55">{isExcluded ? "税込合計" : "借方合計"}</span>
          <span className="text-base font-semibold tabular-nums text-foreground">
            ¥{debitTotal.toLocaleString()}
          </span>
        </div>
      </div>

      <div className="h-px bg-black/10 dark:bg-white/10" />

      <div className="flex flex-col gap-2.5">
        <div className="flex items-center justify-between">
          <span className="text-sm font-medium text-foreground">支払い方法</span>
          <button
            type="button"
            onClick={() => setCreditLines((lines) => [...lines, emptyCreditLine()])}
            className="text-sm font-medium text-blue-600 hover:text-blue-700"
          >
            + 支払い方法を追加
          </button>
        </div>

        <div className="flex flex-col gap-2">
          {creditLines.map((line) => (
            <div
              key={line.key}
              className="flex items-center gap-2 rounded-lg border border-black/10 p-3 dark:border-white/10"
            >
              <select
                value={line.paymentKey}
                onChange={(e) => updateCreditLine(line.key, { paymentKey: e.target.value })}
                required
                className={`${lineInputClass} min-w-0 flex-1`}
              >
                <option value="">支払い方法を選択</option>
                <optgroup label="現金・電子マネー">
                  {paymentAccounts
                    .filter((a) => a.category === "asset")
                    .map((a) => (
                      <option key={paymentKey(a)} value={paymentKey(a)}>
                        {a.name}
                      </option>
                    ))}
                </optgroup>
                <optgroup label="クレジットカード等">
                  {paymentAccounts
                    .filter((a) => a.category === "liability")
                    .map((a) => (
                      <option key={paymentKey(a)} value={paymentKey(a)}>
                        {a.name}
                      </option>
                    ))}
                </optgroup>
              </select>
              <div className="relative w-28 shrink-0">
                <span className="pointer-events-none absolute inset-y-0 left-2.5 flex items-center text-sm text-black/40 dark:text-white/40">
                  ¥
                </span>
                <input
                  type="number"
                  min="1"
                  value={autoCreditAmount ? String(debitTotal) : line.amount}
                  onChange={(e) => updateCreditLine(line.key, { amount: e.target.value })}
                  readOnly={autoCreditAmount}
                  required
                  className={`${lineInputClass} w-full pl-6 text-right ${autoCreditAmount ? "bg-black/5 dark:bg-white/5" : ""}`}
                />
              </div>
              <button
                type="button"
                onClick={() => removeCreditLine(line.key)}
                disabled={creditLines.length === 1}
                aria-label="この支払い方法を削除"
                className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-black/35 hover:text-red-600 disabled:cursor-not-allowed disabled:opacity-30 dark:text-white/35"
              >
                <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                  <path
                    d="M3.5 4.5h9M6.5 4.5V3a1 1 0 0 1 1-1h1a1 1 0 0 1 1 1v1.5M4.5 4.5l.6 8a1 1 0 0 0 1 .9h3.8a1 1 0 0 0 1-.9l.6-8"
                    stroke="currentColor"
                    strokeWidth="1.3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </button>
            </div>
          ))}
        </div>

        <div className="flex items-baseline justify-between pt-0.5">
          <span className="text-sm text-black/55 dark:text-white/55">貸方合計</span>
          <span className="text-base font-semibold tabular-nums text-foreground">
            ¥{creditTotal.toLocaleString()}
          </span>
        </div>

        {(debitTotal > 0 || creditTotal > 0) && (
          <div
            className={
              isBalanced
                ? "inline-flex w-fit items-center gap-1.5 rounded-full bg-green-50 px-2.5 py-1 text-xs font-medium text-green-700 dark:bg-green-900/30 dark:text-green-300"
                : "inline-flex w-fit items-center gap-1.5 rounded-full bg-amber-50 px-2.5 py-1 text-xs font-medium text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
            }
          >
            {isBalanced && (
              <svg width="12" height="12" viewBox="0 0 16 16" fill="none">
                <path
                  d="M3 8.5l3 3 7-7"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            )}
            {isBalanced
              ? "貸借一致"
              : `貸借差額 ¥${Math.abs(debitTotal - creditTotal).toLocaleString()}`}
          </div>
        )}
      </div>

      <button
        type="submit"
        disabled={isSubmitting || !isBalanced}
        className="mt-2 inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {submitLabel}
      </button>
    </form>
  );
}
