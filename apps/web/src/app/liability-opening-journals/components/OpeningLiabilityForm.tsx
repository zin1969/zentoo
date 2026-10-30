"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createOpeningLiability } from "../actions/createOpeningLiability";
import { LiabilityAccount, getLiabilityAccounts } from "@/lib/masters/liabilityAccounts";
import { ApiError, type ApiErrorBody } from "@/lib/api/apiFetch";

type Status = "idle" | "submitting" | "success" | "error";

// liability-accounts の payment_method_type（3 = クレジットカード）
const CREDIT_CARD_PAYMENT_METHOD_TYPE = 3;

function extractErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    const data: ApiErrorBody = error.data ?? {};

    if (Array.isArray(data?.errors) && data.errors.length > 0) {
      return data.errors.join(" / ");
    }

    if (data?.error === "opening_liability_already_exists") {
      return "このカードの、この引き落とし日の未払いは既に登録されています。";
    }

    if (data?.error === "liability_account_not_found") {
      return "選択したカードが見つかりません。画面を再読み込みしてください。";
    }

    if (data?.error === "payment_date_before_journal_date") {
      return "引き落とし日は、開始日以降の日付を指定してください（開始日より前に支払い済みのものは未払いではありません）。";
    }

    if (data?.error === "credit_card_setting_not_found") {
      return "このカードには引き落とし設定（締日・支払日・引き落とし口座）がないため登録できません。";
    }
  }

  return "登録に失敗しました。時間をおいて再度お試しください。";
}

// 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する。
function isUnauthorized(error: unknown): boolean {
  return error instanceof ApiError && error.status === 401;
}

export default function OpeningLiabilityForm() {
  const router = useRouter();
  const [journalDate, setJournalDate] = useState("");
  const [liabilityAccountId, setLiabilityAccountId] = useState("");
  const [amount, setAmount] = useState("");
  const [paymentDate, setPaymentDate] = useState("");
  const [cards, setCards] = useState<LiabilityAccount[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    getLiabilityAccounts()
      .then((accounts) =>
        setCards(accounts.filter((a) => a.payment_method_type === CREDIT_CARD_PAYMENT_METHOD_TYPE))
      )
      .catch((error) => {
        if (isUnauthorized(error)) {
          router.replace("/login");
          return;
        }

        setStatus("error");
        setErrorMessage("カードの取得に失敗しました。時間をおいて再度お試しください。");
      });
  }, [router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setErrorMessage(null);

    try {
      await createOpeningLiability({
        journal_date: journalDate,
        liability_account_id: Number(liabilityAccountId),
        amount: Number(amount),
        payment_date: paymentDate
      });

      setStatus("success");
      // 開始日は続けて登録するときに同じ値を使うので残す
      setLiabilityAccountId("");
      setAmount("");
      setPaymentDate("");
    } catch (error) {
      if (isUnauthorized(error)) {
        router.replace("/login");
        return;
      }

      setStatus("error");
      setErrorMessage(extractErrorMessage(error));
    }
  };

  const isSubmitting = status === "submitting";
  const inputClass =
    "rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";

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

      {status === "error" && errorMessage && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {errorMessage}
        </p>
      )}

      <div className="flex flex-col gap-1.5">
        <label htmlFor="journal-date" className="text-sm font-medium text-foreground">
          開始日
        </label>
        <input
          id="journal-date"
          type="date"
          value={journalDate}
          onChange={(e) => setJournalDate(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="liability-account" className="text-sm font-medium text-foreground">
          カード
        </label>
        <select
          id="liability-account"
          value={liabilityAccountId}
          onChange={(e) => setLiabilityAccountId(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">選択してください</option>
          {cards.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name}
            </option>
          ))}
        </select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="amount" className="text-sm font-medium text-foreground">
          未払いの金額
        </label>
        <div className="relative">
          <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-black/40 dark:text-white/40">
            ¥
          </span>
          <input
            id="amount"
            type="number"
            min="1"
            step="1"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
            className={`${inputClass} w-full pl-7 text-right`}
          />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="payment-date" className="text-sm font-medium text-foreground">
          引き落とし日
        </label>
        <input
          id="payment-date"
          type="date"
          value={paymentDate}
          min={journalDate || undefined}
          onChange={(e) => setPaymentDate(e.target.value)}
          required
          className={inputClass}
        />
        <p className="text-xs text-black/50 dark:text-white/50">カードの明細にある支払日を、そのまま入力してください。</p>
      </div>

      <button
        type="submit"
        disabled={isSubmitting}
        className="mt-2 inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {isSubmitting ? "登録中..." : "登録"}
      </button>
    </form>
  );
}
