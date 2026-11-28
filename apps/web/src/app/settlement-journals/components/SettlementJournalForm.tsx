"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import {
  NON_RECEIVABLE_ASSET_TYPES,
  RECEIVABLE_ASSET_TYPE,
  getAssetAccounts,
  type AssetAccount
} from "@/lib/masters/assetAccounts";
import { getExpenseAccounts } from "@/lib/masters/expenseAccounts";
import { getRevenueAccounts } from "@/lib/masters/revenueAccounts";
import type { TwoLevelAccount } from "@/lib/masters/twoLevelAccounts";
import { getAccountBalances } from "@/lib/reports/accountBalances";
import { createSettlementJournal, updateSettlementJournal } from "@/lib/journals/settlementJournals";
import type { Journal } from "@/lib/journals/journals";
import { localToday } from "@/lib/dates/localToday";

type Status = "idle" | "submitting" | "success" | "error";

const MAX_DESCRIPTION_LENGTH = 100;
const ASSET_ELEMENT_TYPE = 1;
const REVENUE_ELEMENT_TYPE = 4;
const EXPENSE_ELEMENT_TYPE = 5;

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

// 親子 2 階層の科目を、「親 / 子」の名前で 1 つの一覧にする
function flattenAccounts(accounts: TwoLevelAccount[]) {
  const byId = new Map(accounts.map((a) => [a.id, a]));
  const tops = accounts.filter((a) => a.parent_id === null || !byId.has(a.parent_id));

  return tops.flatMap((top) => [
    { id: top.id, label: top.name },
    ...accounts.filter((a) => a.parent_id === top.id).map((child) => ({ id: child.id, label: `${top.name} / ${child.name}` }))
  ]);
}

function errorMessage(error: unknown, isEdit: boolean) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "receivable_account_not_found":
        return "立替金の口座が見つかりません。画面を再読み込みしてください。";
      case "to_account_not_found":
        return "入金先の口座が見つかりません。画面を再読み込みしてください。";
      case "difference_account_not_found":
        return "差額の科目が見つかりません。選び直してください。";
      case "journal_not_found":
        return "修正する仕訳が見つかりません。すでに削除されている可能性があります。";
      case "journal_not_editable":
        return "この仕訳は精算の仕訳ではないため、ここでは修正できません。";
    }

    if (error.data?.errors?.length) {
      return error.data.errors.join(" / ");
    }
  }

  return isEdit
    ? "修正に失敗しました。時間をおいて再度お試しください。"
    : "登録に失敗しました。時間をおいて再度お試しください。";
}

// 修正のときは、元の仕訳から初期値を取り出す
function initialValues(journal?: Journal) {
  const receivable = journal?.credits.find(
    (c) => c.element_type === ASSET_ELEMENT_TYPE && c.payment_method_type === RECEIVABLE_ASSET_TYPE
  );
  const to = journal?.debits.find((d) => d.element_type === ASSET_ELEMENT_TYPE);
  const difference =
    journal?.debits.find((d) => d.element_type === EXPENSE_ELEMENT_TYPE) ??
    journal?.credits.find((c) => c.element_type === REVENUE_ELEMENT_TYPE);

  return {
    receivableId: receivable ? String(receivable.account_id) : "",
    settledAmount: receivable ? String(receivable.amount) : "",
    receivedAmount: journal ? String(to?.amount ?? 0) : "",
    toAccountId: to ? String(to.account_id) : "",
    differenceAccountId: difference ? String(difference.account_id) : ""
  };
}

type Props = {
  // 渡されたときは修正。元の仕訳の内容で開き、送信すると作り直して仕訳一覧に戻る
  journal?: Journal;
};

// 立替金の精算（返してもらった額の登録。差額は費用か収益）の登録・修正
export default function SettlementJournalForm({ journal }: Props = {}) {
  const isEdit = journal !== undefined;
  const router = useRouter();
  const initial = initialValues(journal);

  const [date, setDate] = useState(journal?.journal_date ?? localToday());
  const [receivableId, setReceivableId] = useState(initial.receivableId);
  const [settledAmount, setSettledAmount] = useState(initial.settledAmount);
  const [receivedAmount, setReceivedAmount] = useState(initial.receivedAmount);
  const [toAccountId, setToAccountId] = useState(initial.toAccountId);
  const [differenceAccountId, setDifferenceAccountId] = useState(initial.differenceAccountId);
  const [description, setDescription] = useState(journal?.store_name ?? "");

  const [assetAccounts, setAssetAccounts] = useState<AssetAccount[]>([]);
  const [expenseAccounts, setExpenseAccounts] = useState<TwoLevelAccount[]>([]);
  const [revenueAccounts, setRevenueAccounts] = useState<TwoLevelAccount[]>([]);
  const [balances, setBalances] = useState<Map<number, number>>(new Map());
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    Promise.all([getAssetAccounts(), getExpenseAccounts(), getRevenueAccounts(), getAccountBalances()])
      .then(([assets, expenses, revenues, accountBalances]) => {
        if (cancelled) return;

        setAssetAccounts(assets);
        setExpenseAccounts(expenses);
        setRevenueAccounts(revenues);
        setBalances(new Map(accountBalances.assets.map((a) => [a.account_id, a.balance])));
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

  const receivables = assetAccounts.filter((a) => a.payment_method_type === RECEIVABLE_ASSET_TYPE);
  const receivableBalance = receivableId ? balances.get(Number(receivableId)) : undefined;

  const settled = Number(settledAmount) || 0;
  const received = Number(receivedAmount) || 0;
  const difference = settled - received;
  const differenceAccounts = flattenAccounts(difference > 0 ? expenseAccounts : revenueAccounts);

  // 立替金を選んだら、消し込む額を今の残高にする（登録のときだけ。修正では元の額のまま）
  const selectReceivable = (id: string) => {
    setReceivableId(id);

    const balance = balances.get(Number(id));
    if (!isEdit && balance !== undefined && balance > 0) {
      setSettledAmount(String(balance));
      if (receivedAmount === "") setReceivedAmount(String(balance));
    }
  };

  // 差額の向き（費用・収益）が変わったら、科目を選び直してもらう
  const changeReceived = (value: string) => {
    const nextDifference = settled - (Number(value) || 0);
    if (Math.sign(nextDifference) !== Math.sign(difference)) setDifferenceAccountId("");
    setReceivedAmount(value);
  };

  const changeSettled = (value: string) => {
    const nextDifference = (Number(value) || 0) - received;
    if (Math.sign(nextDifference) !== Math.sign(difference)) setDifferenceAccountId("");
    setSettledAmount(value);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setError(null);

    const input = {
      journal_date: date,
      receivable_account_id: Number(receivableId),
      settled_amount: settled,
      received_amount: received,
      to_account_id: received > 0 ? Number(toAccountId) : null,
      difference_account_id: difference !== 0 ? Number(differenceAccountId) : null,
      description: description.trim()
    };

    try {
      if (isEdit && journal) {
        await updateSettlementJournal(journal.id, input);
        router.push("/journals");
        return;
      }

      await createSettlementJournal(input);

      setStatus("success");
      setReceivableId("");
      setSettledAmount("");
      setReceivedAmount("");
      setDifferenceAccountId("");
      setDescription("");

      // 精算した分を反映した残高を出し直す
      getAccountBalances()
        .then((accountBalances) => setBalances(new Map(accountBalances.assets.map((a) => [a.account_id, a.balance]))))
        .catch(() => {});
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
  const hintClass = "text-xs text-black/50 dark:text-white/50";

  const yenInput = (id: string, value: string, onChange: (value: string) => void, min: string) => (
    <div className="relative">
      <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-black/40 dark:text-white/40">
        ¥
      </span>
      <input
        id={id}
        type="number"
        min={min}
        step="1"
        inputMode="numeric"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        required
        className={`${inputClass} w-full pl-7 text-right`}
      />
    </div>
  );

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
        <label htmlFor="settlement-date" className={labelClass}>
          日付
        </label>
        <input
          id="settlement-date"
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="settlement-receivable" className={labelClass}>
          立替金
        </label>
        <select
          id="settlement-receivable"
          value={receivableId}
          onChange={(e) => selectReceivable(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">立替金の口座を選択</option>
          {receivables.map((account) => (
            <option key={account.id} value={account.id}>
              {account.name}
            </option>
          ))}
        </select>
        {receivableBalance !== undefined && <span className={hintClass}>今日時点の残り {formatYen(receivableBalance)}</span>}
        {assetAccounts.length > 0 && receivables.length === 0 && (
          <span className={hintClass}>
            立替金の口座がありません。「口座・カード・科目・タグの管理」で、種別「立替金」の口座を相手ごとに作ってください（例: 立替金 田中、立替金 会社）。
          </span>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="settlement-settled" className={labelClass}>
          消し込む額
        </label>
        {yenInput("settlement-settled", settledAmount, changeSettled, "1")}
        <span className={hintClass}>立替金から減らす額。会社の精算なら、精算書に書いた額です。</span>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="settlement-received" className={labelClass}>
          受け取った額
        </label>
        {yenInput("settlement-received", receivedAmount, changeReceived, "0")}
        <span className={hintClass}>全額おごりになったときは 0 にします。</span>
      </div>

      {received > 0 && (
        <div className="flex flex-col gap-1.5">
          <label htmlFor="settlement-to" className={labelClass}>
            入金先
          </label>
          <select
            id="settlement-to"
            value={toAccountId}
            onChange={(e) => setToAccountId(e.target.value)}
            required
            className={inputClass}
          >
            <option value="">入金先を選択</option>
            {NON_RECEIVABLE_ASSET_TYPES.map((type) => (
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
      )}

      {settled > 0 && difference !== 0 && (
        <div className="flex flex-col gap-1.5 rounded-md bg-black/5 p-3 dark:bg-white/5">
          <label htmlFor="settlement-difference" className={labelClass}>
            {difference > 0 ? `足りない ${formatYen(difference)} の費用科目` : `多い ${formatYen(-difference)} の収益科目`}
          </label>
          <select
            id="settlement-difference"
            value={differenceAccountId}
            onChange={(e) => setDifferenceAccountId(e.target.value)}
            required
            className={inputClass}
          >
            <option value="">科目を選択</option>
            {differenceAccounts.map((account) => (
              <option key={account.id} value={account.id}>
                {account.label}
              </option>
            ))}
          </select>
          <span className={hintClass}>
            {difference > 0
              ? "会社に認められなかった分や、おごりになった分は、自分の支出になります。"
              : "多く受け取った分は収入になります。"}
          </span>
        </div>
      )}

      <div className="flex flex-col gap-1.5">
        <label htmlFor="settlement-description" className={labelClass}>
          摘要（任意）
        </label>
        <input
          id="settlement-description"
          type="text"
          placeholder="空なら「精算 立替金の口座名」になります"
          value={description}
          maxLength={MAX_DESCRIPTION_LENGTH}
          onChange={(e) => setDescription(e.target.value)}
          className={inputClass}
        />
      </div>

      <button
        type="submit"
        disabled={isSubmitting}
        className="mt-2 inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {isSubmitting ? `${actionLabel}中...` : actionLabel}
      </button>
    </form>
  );
}
