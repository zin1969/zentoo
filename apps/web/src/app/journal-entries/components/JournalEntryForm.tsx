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

type Status = "idle" | "submitting" | "success" | "error";

const EXPENSE_ELEMENT_TYPE = 5;

type DebitLine = {
  key: string;
  itemName: string;
  // 選んだ親の科目。空なら、選んだ科目（expenseAccountId）からたどる（修正で開いたとき）
  parentId: string;
  // 登録する科目。子科目か、親の科目そのもの（「〇〇のまま」）
  expenseAccountId: string;
  amount: string;
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
  return { key: nextKey(), itemName: "", parentId: "", expenseAccountId: "", amount: "" };
}

function emptyCreditLine(): CreditLine {
  return { key: nextKey(), paymentKey: "", amount: "" };
}

// 修正のときは、元の仕訳の内容をフォームの初期値にする
function debitLinesFrom(journal: Journal): DebitLine[] {
  return journal.debits.map((debit) => ({
    key: nextKey(),
    itemName: debit.item_name ?? "",
    parentId: "",
    expenseAccountId: String(debit.account_id),
    amount: String(debit.amount)
  }));
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
};

export default function JournalEntryForm({ journal }: JournalEntryFormProps = {}) {
  const isEdit = journal !== undefined;
  const router = useRouter();
  const [date, setDate] = useState(journal?.journal_date ?? "");
  const [storeName, setStoreName] = useState(journal?.store_name ?? "");
  const [debitLines, setDebitLines] = useState<DebitLine[]>(() =>
    journal ? debitLinesFrom(journal) : [emptyDebitLine()]
  );
  const [creditLines, setCreditLines] = useState<CreditLine[]>(() =>
    journal ? creditLinesFrom(journal) : [emptyCreditLine()]
  );

  const [expenseAccounts, setExpenseAccounts] = useState<ExpenseAccount[]>([]);
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

  const debitTotal = sumAmounts(debitLines.map((l) => l.amount));
  const creditTotal = sumAmounts(creditLines.map((l) => l.amount));
  const isBalanced = debitTotal > 0 && debitTotal === creditTotal;

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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setErrorMessage(null);

    try {
      const body = {
        date,
        store_name: storeName,
        debits: debitLines.map((line) => ({
          element_type: EXPENSE_ELEMENT_TYPE,
          account_id: Number(line.expenseAccountId),
          amount: Number(line.amount),
          item_name: line.itemName
        })),
        credits: creditLines.map((line) => {
          const account = paymentAccounts.find((a) => paymentKey(a) === line.paymentKey);

          return {
            element_type: account?.element_type,
            payment_method_type: account?.payment_method_type,
            account_id: account?.id,
            amount: Number(line.amount)
          };
        })
      };

      if (journal) {
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
            </div>
          ))}
        </div>

        <div className="flex items-baseline justify-between pt-0.5">
          <span className="text-sm text-black/55 dark:text-white/55">借方合計</span>
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
                  value={line.amount}
                  onChange={(e) => updateCreditLine(line.key, { amount: e.target.value })}
                  required
                  className={`${lineInputClass} w-full pl-6 text-right`}
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
