"use client";

import { useEffect, useState } from "react";
import { createJournalEntry } from "../actions/createJournalEntry";
import { ExpenseAccount, getExpenseAccounts } from "@/lib/masters/expenseAccounts";
import { getAssetAccounts } from "@/lib/masters/assetAccounts";
import { getLiabilityAccounts } from "@/lib/masters/liabilityAccounts";
import { ApiError } from "@/lib/api/apiFetch";

type Status = "idle" | "submitting" | "success" | "error";

const EXPENSE_ELEMENT_TYPE = 5;

type DebitLine = {
  key: string;
  itemName: string;
  expenseAccountId: string;
  amount: string;
};

type CreditLine = {
  key: string;
  paymentAccountId: string;
  amount: string;
};

type PaymentAccount = {
  id: number;
  name: string;
  element_type: number;
  payment_method_type: number;
  category: "asset" | "liability";
};

let lineKeySeq = 0;
function nextKey() {
  lineKeySeq += 1;
  return `line-${lineKeySeq}`;
}

function emptyDebitLine(): DebitLine {
  return { key: nextKey(), itemName: "", expenseAccountId: "", amount: "" };
}

function emptyCreditLine(): CreditLine {
  return { key: nextKey(), paymentAccountId: "", amount: "" };
}

function sumAmounts(amounts: string[]) {
  return amounts.reduce((total, a) => total + (Number(a) || 0), 0);
}

function extractErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    const data = error.data;

    if (Array.isArray(data?.errors) && data.errors.length > 0) {
      return data.errors.join(" / ");
    }

    if (data?.error === "unbalanced_journal") {
      return "貸方と借方の合計金額が一致していません。";
    }

    if (typeof data?.message === "string") {
      return data.message;
    }

    if (error.status === 401) {
      return "認証の有効期限が切れました。再度ログインしてください。";
    }
  }

  return "登録に失敗しました。時間をおいて再度お試しください。";
}

export default function JournalEntryForm() {
  const [date, setDate] = useState("");
  const [storeName, setStoreName] = useState("");
  const [debitLines, setDebitLines] = useState<DebitLine[]>([emptyDebitLine()]);
  const [creditLines, setCreditLines] = useState<CreditLine[]>([emptyCreditLine()]);

  const [expenseAccounts, setExpenseAccounts] = useState<ExpenseAccount[]>([]);
  const [paymentAccounts, setPaymentAccounts] = useState<PaymentAccount[]>([]);

  const [status, setStatus] = useState<Status>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    getExpenseAccounts()
      .then(setExpenseAccounts)
      .catch(() => setErrorMessage("勘定科目の取得に失敗しました。時間をおいて再度お試しください。"));

    Promise.all([getAssetAccounts(), getLiabilityAccounts()])
      .then(([assetAccounts, liabilityAccounts]) => {
        setPaymentAccounts([
          ...assetAccounts.map((a) => ({ ...a, category: "asset" as const })),
          ...liabilityAccounts.map((a) => ({ ...a, category: "liability" as const }))
        ]);
      })
      .catch(() => setErrorMessage("支払い方法の取得に失敗しました。時間をおいて再度お試しください。"));
  }, []);

  const debitTotal = sumAmounts(debitLines.map((l) => l.amount));
  const creditTotal = sumAmounts(creditLines.map((l) => l.amount));
  const isBalanced = debitTotal > 0 && debitTotal === creditTotal;

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
      await createJournalEntry({
        date,
        // Rails 側の InsertJournalEntryForm は user_id の presence バリデーションを持つが、
        // controller が認証済みユーザーの ID で必ず上書きするため、ここではダミー値でよい。
        user_id: 0,
        store_name: storeName,
        debits: debitLines.map((line) => ({
          element_type: EXPENSE_ELEMENT_TYPE,
          account_id: Number(line.expenseAccountId),
          amount: Number(line.amount),
          item_name: line.itemName
        })),
        credits: creditLines.map((line) => {
          const account = paymentAccounts.find((a) => a.id === Number(line.paymentAccountId));

          return {
            element_type: account?.element_type,
            payment_method_type: account?.payment_method_type,
            account_id: Number(line.paymentAccountId),
            amount: Number(line.amount)
          };
        })
      });

      setStatus("success");
      setDate("");
      setStoreName("");
      setDebitLines([emptyDebitLine()]);
      setCreditLines([emptyCreditLine()]);
    } catch (error) {
      setStatus("error");
      setErrorMessage(extractErrorMessage(error));
    }
  };

  const isSubmitting = status === "submitting";
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
                  value={line.expenseAccountId}
                  onChange={(e) => updateDebitLine(line.key, { expenseAccountId: e.target.value })}
                  required
                  className={`${lineInputClass} min-w-0 flex-1`}
                >
                  <option value="">勘定科目を選択</option>
                  {expenseAccounts.map((a) => (
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
                value={line.paymentAccountId}
                onChange={(e) => updateCreditLine(line.key, { paymentAccountId: e.target.value })}
                required
                className={`${lineInputClass} min-w-0 flex-1`}
              >
                <option value="">支払い方法を選択</option>
                <optgroup label="資産">
                  {paymentAccounts
                    .filter((a) => a.category === "asset")
                    .map((a) => (
                      <option key={`asset-${a.id}`} value={a.id}>
                        {a.name}
                      </option>
                    ))}
                </optgroup>
                <optgroup label="負債">
                  {paymentAccounts
                    .filter((a) => a.category === "liability")
                    .map((a) => (
                      <option key={`liability-${a.id}`} value={a.id}>
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
        {isSubmitting ? "登録中..." : "登録"}
      </button>
    </form>
  );
}
