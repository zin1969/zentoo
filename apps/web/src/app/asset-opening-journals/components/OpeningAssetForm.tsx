"use client";

import { useEffect, useState } from "react";
import { createOpeningAsset } from "../actions/createOpeningAsset";
import { AssetAccount, getAssetAccounts } from "@/lib/masters/assetAccounts";
import { ApiError } from "@/lib/api/apiFetch";

type Status = "idle" | "submitting" | "success" | "error";

function extractErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    const data = error.data;

    if (Array.isArray(data?.errors) && data.errors.length > 0) {
      return data.errors.join(" / ");
    }

    if (typeof data?.message === "string") {
      return data.message;
    }

    if (data?.error === "opening_asset_already_exists") {
      return "この勘定科目の開始残高は既に登録されています。";
    }

    if (error.status === 401) {
      return "認証の有効期限が切れました。再度ログインしてください。";
    }
  }

  return "登録に失敗しました。時間をおいて再度お試しください。";
}

export default function OpeningAssetForm() {
  const [journalDate, setJournalDate] = useState("");
  const [assetAccountId, setAssetAccountId] = useState("");
  const [amount, setAmount] = useState("");
  const [assetAccounts, setAssetAccounts] = useState<AssetAccount[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    getAssetAccounts().then(setAssetAccounts);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setErrorMessage(null);

    try {
      await createOpeningAsset({
        journal_date: journalDate,
        asset_type: 1,
        asset_account_id: Number(assetAccountId),
        amount: Number(amount)
      });

      setStatus("success");
      setJournalDate("");
      setAssetAccountId("");
      setAmount("");
    } catch (error) {
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
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
            className={`${inputClass} w-full pl-7 text-right`}
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
