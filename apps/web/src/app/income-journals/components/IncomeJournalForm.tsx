"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { ASSET_TYPES, getAssetAccounts, type AssetAccount } from "@/lib/masters/assetAccounts";
import { getRevenueAccounts, type RevenueAccount } from "@/lib/masters/revenueAccounts";
import { createIncomeJournal, updateIncomeJournal } from "@/lib/journals/incomeJournals";
import type { Journal } from "@/lib/journals/journals";
import { localToday } from "@/lib/dates/localToday";

type Status = "idle" | "submitting" | "success" | "error";

const MAX_DESCRIPTION_LENGTH = 100;

function errorMessage(error: unknown, isEdit: boolean) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "asset_account_not_found":
        return "入金先の口座が見つかりません。画面を再読み込みしてください。";
      case "revenue_account_not_found":
        return "収益科目が見つかりません。画面を再読み込みしてください。";
      case "journal_not_found":
        return "修正する仕訳が見つかりません。すでに削除されている可能性があります。";
      case "journal_not_editable":
        return "この仕訳は収入の仕訳ではないため、ここでは修正できません。";
    }

    if (error.data?.errors?.length) {
      return error.data.errors.join(" / ");
    }
  }

  return isEdit
    ? "修正に失敗しました。時間をおいて再度お試しください。"
    : "登録に失敗しました。時間をおいて再度お試しください。";
}

type Props = {
  // 渡されたときは修正。元の仕訳の内容で開き、送信すると作り直して仕訳一覧に戻る
  journal?: Journal;
  // true のときは、journal の内容をコピーした新しい登録（日付は今日。元の仕訳は変えない）
  copy?: boolean;
};

// 収入（借方: 入金先の口座、貸方: 収益科目）の登録・修正
export default function IncomeJournalForm({ journal, copy = false }: Props = {}) {
  const isEdit = journal !== undefined && !copy;
  const router = useRouter();

  const [date, setDate] = useState(copy ? localToday() : (journal?.journal_date ?? ""));
  const [assetAccountId, setAssetAccountId] = useState(String(journal?.debits[0]?.account_id ?? ""));
  // 選んだ親の科目。空なら、選んだ科目（revenueAccountId）からたどる（修正で開いたとき）
  const [parentId, setParentId] = useState("");
  const [revenueAccountId, setRevenueAccountId] = useState(String(journal?.credits[0]?.account_id ?? ""));
  const [amount, setAmount] = useState(String(journal?.credits[0]?.amount ?? ""));
  const [description, setDescription] = useState(journal?.store_name ?? "");

  const [assetAccounts, setAssetAccounts] = useState<AssetAccount[]>([]);
  const [revenueAccounts, setRevenueAccounts] = useState<RevenueAccount[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    Promise.all([getAssetAccounts(), getRevenueAccounts()])
      .then(([assets, revenues]) => {
        if (cancelled) return;

        setAssetAccounts(assets);
        setRevenueAccounts(revenues);
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setError("口座・科目の取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [router]);

  // 親の科目を選んでから、その子科目を選ぶ。合う子科目が無いときは、親のままでも登録できる
  const hasAccount = (id: number | null) => id !== null && revenueAccounts.some((a) => a.id === id);
  const topLevel = revenueAccounts.filter((a) => !hasAccount(a.parent_id));
  const childrenOf = (id: string) => revenueAccounts.filter((a) => String(a.parent_id) === id);

  const selectedParentId = (() => {
    if (parentId) return parentId;

    const account = revenueAccounts.find((a) => String(a.id) === revenueAccountId);
    if (!account) return "";

    return String(hasAccount(account.parent_id) ? account.parent_id : account.id);
  })();
  const children = selectedParentId ? childrenOf(selectedParentId) : [];
  const parentName = revenueAccounts.find((a) => String(a.id) === selectedParentId)?.name;

  const selectParent = (id: string) => {
    setParentId(id);
    // 子科目があれば、子科目か「〇〇のまま」を選び直してもらう
    setRevenueAccountId(childrenOf(id).length > 0 ? "" : id);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setError(null);

    const input = {
      journal_date: date,
      asset_account_id: Number(assetAccountId),
      revenue_account_id: Number(revenueAccountId),
      amount: Number(amount),
      description: description.trim()
    };

    try {
      if (isEdit && journal) {
        await updateIncomeJournal(journal.id, input);
        router.push("/journals");
        return;
      }

      await createIncomeJournal(input);

      setStatus("success");
      setDate("");
      setParentId("");
      setRevenueAccountId("");
      setAmount("");
      setDescription("");
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        router.replace("/login");
        return;
      }

      setStatus("error");
      setError(errorMessage(err, isEdit));
    }
  };

  const isSubmitting = status === "submitting";
  const actionLabel = isEdit ? "修正" : "登録";
  const inputClass =
    "rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";
  const labelClass = "text-sm font-medium text-foreground";

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

      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {error}
        </p>
      )}

      <div className="flex flex-col gap-1.5">
        <label htmlFor="income-date" className={labelClass}>
          日付
        </label>
        <input
          id="income-date"
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="income-asset-account" className={labelClass}>
          入金先
        </label>
        <select
          id="income-asset-account"
          value={assetAccountId}
          onChange={(e) => setAssetAccountId(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">入金先を選択</option>
          {ASSET_TYPES.map((type) => (
            <optgroup key={type.value} label={type.label}>
              {assetAccounts
                .filter((account) => account.payment_method_type === type.value)
                .map((account) => (
                  <option key={account.id} value={account.id}>
                    {account.name}
                  </option>
                ))}
            </optgroup>
          ))}
        </select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="income-revenue-account" className={labelClass}>
          収益科目
        </label>
        <select
          id="income-revenue-account"
          value={selectedParentId}
          onChange={(e) => selectParent(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">収益科目を選択</option>
          {topLevel.map((account) => (
            <option key={account.id} value={account.id}>
              {account.name}
            </option>
          ))}
        </select>
        {children.length > 0 && (
          <select
            aria-label="子科目"
            value={revenueAccountId}
            onChange={(e) => setRevenueAccountId(e.target.value)}
            required
            className={inputClass}
          >
            <option value="">子科目を選択</option>
            <option value={selectedParentId}>（{parentName}のまま）</option>
            {children.map((account) => (
              <option key={account.id} value={account.id}>
                {account.name}
              </option>
            ))}
          </select>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="income-amount" className={labelClass}>
          金額
        </label>
        <div className="relative">
          <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-black/40 dark:text-white/40">
            ¥
          </span>
          <input
            id="income-amount"
            type="number"
            min="1"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
            className={`${inputClass} w-full pl-7 text-right`}
          />
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="income-description" className={labelClass}>
          摘要（任意）
        </label>
        <input
          id="income-description"
          type="text"
          placeholder="支払元など。空なら収益科目の名前になります"
          value={description}
          maxLength={MAX_DESCRIPTION_LENGTH}
          onChange={(e) => setDescription(e.target.value)}
          className={inputClass}
        />
      </div>

      <button
        type="submit"
        disabled={isSubmitting || !revenueAccountId}
        className="mt-2 inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {isSubmitting ? `${actionLabel}中...` : actionLabel}
      </button>
    </form>
  );
}
