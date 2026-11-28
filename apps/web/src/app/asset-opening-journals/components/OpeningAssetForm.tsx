"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createOpeningAsset } from "../actions/createOpeningAsset";
import { AssetAccount, getAssetAccounts } from "@/lib/masters/assetAccounts";
import { ApiError, type ApiErrorBody } from "@/lib/api/apiFetch";

type Status = "idle" | "submitting" | "success" | "error";

function extractErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    const data: ApiErrorBody = error.data ?? {};

    if (Array.isArray(data?.errors) && data.errors.length > 0) {
      return data.errors.join(" / ");
    }

    if (typeof data?.message === "string") {
      return data.message;
    }

    if (data?.error === "opening_asset_already_exists") {
      return "この勘定科目の開始残高は既に登録されています。";
    }

    if (data?.error === "asset_account_not_found") {
      return "選択した勘定科目が見つかりません。画面を再読み込みしてください。";
    }

    if (data?.error === "shares_require_investment_account") {
      return "株数を入れられるのは、種別「投資」の口座（株の銘柄）だけです。";
    }

    if (data?.error === "later_sale_exists") {
      return "この銘柄には、もっと後の日付の売りがあります。先にその売りを仕訳一覧で削除してください。";
    }

  }

  return "登録に失敗しました。時間をおいて再度お試しください。";
}

const INVESTMENT = 5;

// 株数 × 平均取得単価（円未満は四捨五入）。どちらかが空なら null
function stockAmount(shares: string, averagePrice: string) {
  const sharesNumber = Number(shares);
  const priceNumber = Number(averagePrice);
  if (!shares || !averagePrice || !(sharesNumber > 0) || !(priceNumber > 0)) return null;

  return Math.round(sharesNumber * priceNumber);
}

// 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する。
function isUnauthorized(error: unknown): boolean {
  return error instanceof ApiError && error.status === 401;
}

export default function OpeningAssetForm() {
  const router = useRouter();
  const [journalDate, setJournalDate] = useState("");
  const [assetAccountId, setAssetAccountId] = useState("");
  const [amount, setAmount] = useState("");
  // 株の銘柄（種別「投資」の口座）のときだけ。入れると金額は 株数 × 平均取得単価 になる
  const [shares, setShares] = useState("");
  const [averagePrice, setAveragePrice] = useState("");
  const [assetAccounts, setAssetAccounts] = useState<AssetAccount[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    getAssetAccounts()
      .then(setAssetAccounts)
      .catch((error) => {
        if (isUnauthorized(error)) {
          router.replace("/login");
          return;
        }

        setStatus("error");
        setErrorMessage("勘定科目の取得に失敗しました。時間をおいて再度お試しください。");
      });
  }, [router]);

  const selectedAccount = assetAccounts.find((a) => String(a.id) === assetAccountId);
  const isInvestment = selectedAccount?.payment_method_type === INVESTMENT;
  const computedAmount = isInvestment ? stockAmount(shares, averagePrice) : null;
  const sendsShares = computedAmount !== null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setErrorMessage(null);

    try {
      await createOpeningAsset({
        journal_date: journalDate,
        asset_type: 1,
        asset_account_id: Number(assetAccountId),
        amount: sendsShares ? computedAmount : Number(amount),
        ...(sendsShares ? { shares: Number(shares) } : {})
      });

      setStatus("success");
      setJournalDate("");
      setAssetAccountId("");
      setAmount("");
      setShares("");
      setAveragePrice("");
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
          日付
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
        <label htmlFor="asset-account" className="text-sm font-medium text-foreground">
          勘定科目
        </label>
        <select
          id="asset-account"
          value={assetAccountId}
          onChange={(e) => setAssetAccountId(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">選択してください</option>
          {assetAccounts.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name}
            </option>
          ))}
        </select>
      </div>

      {isInvestment && (
        <div className="flex flex-col gap-3 rounded-md bg-black/5 p-3 dark:bg-white/5">
          <p className="text-xs text-black/60 dark:text-white/60">
            株の銘柄なら、株数と平均取得単価を入れてください（金額は 株数 × 平均取得単価）。iDeCo・NISA のように株数を持たないものは空のまま金額を入れます。
          </p>
          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <label htmlFor="shares" className="text-sm font-medium text-foreground">
                株数
              </label>
              <input
                id="shares"
                type="number"
                min="1"
                step="1"
                inputMode="numeric"
                value={shares}
                onChange={(e) => setShares(e.target.value)}
                required={averagePrice !== ""}
                className={`${inputClass} text-right`}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label htmlFor="average-price" className="text-sm font-medium text-foreground">
                平均取得単価
              </label>
              <input
                id="average-price"
                type="number"
                min="0.01"
                step="0.01"
                inputMode="decimal"
                value={averagePrice}
                onChange={(e) => setAveragePrice(e.target.value)}
                required={shares !== ""}
                className={`${inputClass} text-right`}
              />
            </div>
          </div>
        </div>
      )}

      <div className="flex flex-col gap-1.5">
        <label htmlFor="amount" className="text-sm font-medium text-foreground">
          金額
        </label>
        <div className="relative">
          <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-black/40 dark:text-white/40">
            ¥
          </span>
          <input
            id="amount"
            type="number"
            min="0"
            value={sendsShares ? String(computedAmount) : amount}
            onChange={(e) => setAmount(e.target.value)}
            readOnly={sendsShares}
            required
            className={`${inputClass} w-full pl-7 text-right ${sendsShares ? "bg-black/5 dark:bg-white/5" : ""}`}
          />
        </div>
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
