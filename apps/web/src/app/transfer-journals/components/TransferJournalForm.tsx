"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { ASSET_TYPES, NON_RECEIVABLE_ASSET_TYPES, getAssetAccounts, type AssetAccount } from "@/lib/masters/assetAccounts";
import { getCreditCards, type CreditCard } from "@/lib/masters/creditCards";
import { createTransferJournal, updateTransferJournal } from "@/lib/journals/transferJournals";
import type { Journal } from "@/lib/journals/journals";
import { localToday } from "@/lib/dates/localToday";

type Status = "idle" | "submitting" | "success" | "error";

const MAX_DESCRIPTION_LENGTH = 100;
const CASH = 1;
const DEPOSIT = 2;
const E_MONEY = 3;
const ASSET_ELEMENT_TYPE = 1;

// 出す元は「口座」と「カード」で ID が重なるので、「asset-ID」「card-ID」で区別する
type FromKey = `asset-${number}` | `card-${number}` | "";

function parseFrom(key: string) {
  const [kind, id] = key.split("-");
  return { fromType: kind === "card" ? ("credit_card" as const) : ("asset" as const), fromId: Number(id) };
}

// 入れる先に選べる口座: 出す元と同じ口座は除く。カードから入れられるのは電子マネーだけ
function isAllowedTo(fromKey: FromKey, account: AssetAccount) {
  if (fromKey === "") return true;

  const { fromType, fromId } = parseFrom(fromKey);
  if (fromType === "credit_card") return account.payment_method_type === E_MONEY;

  return account.id !== fromId;
}

// 摘要を空にしたときに入る名前（DB 関数と同じ決め方）。入力欄の例として出す
function autoLabel(fromType: "asset" | "credit_card", fromAssetType: number | undefined, toAssetType: number | undefined) {
  if (toAssetType === E_MONEY) return "チャージ";
  if (fromType === "asset" && fromAssetType === DEPOSIT && toAssetType === CASH) return "引き出し";
  if (fromType === "asset" && fromAssetType === CASH && toAssetType === DEPOSIT) return "預入";

  return "振替";
}

function errorMessage(error: unknown, isEdit: boolean) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "from_account_not_found":
        return "出す元の口座・カードが見つかりません。画面を再読み込みしてください。";
      case "to_account_not_found":
        return "入れる先の口座が見つかりません。画面を再読み込みしてください。";
      case "same_account":
        return "出す元と入れる先に、同じ口座は選べません。";
      case "credit_card_charge_requires_e_money":
        return "クレジットカードから入れられるのは、電子マネーだけです。";
      case "receivable_requires_settlement":
        return "立替金から返してもらったときは、「立替金の精算」で登録してください。";
      case "credit_card_setting_not_found":
        return "このカードには引き落とし設定がありません。「口座・カード・科目の管理」で登録してください。";
      case "journal_not_found":
        return "修正する仕訳が見つかりません。すでに削除されている可能性があります。";
      case "journal_not_editable":
        return "この仕訳は振替の仕訳ではないため、ここでは修正できません。";
    }

    if (error.data?.errors?.length) {
      return error.data.errors.join(" / ");
    }
  }

  return isEdit
    ? "修正に失敗しました。時間をおいて再度お試しください。"
    : "登録に失敗しました。時間をおいて再度お試しください。";
}

function initialFrom(journal?: Journal): FromKey {
  const credit = journal?.credits[0];
  if (!credit) return "";

  return credit.element_type === ASSET_ELEMENT_TYPE ? `asset-${credit.account_id}` : `card-${credit.account_id}`;
}

type Props = {
  // 渡されたときは修正。元の仕訳の内容で開き、送信すると作り直して仕訳一覧に戻る
  journal?: Journal;
  // true のときは、journal の内容をコピーした新しい登録（日付は今日。元の仕訳は変えない）
  copy?: boolean;
};

// 振替（引き出し・口座間の振替・電子マネーへのチャージ）の登録・修正
export default function TransferJournalForm({ journal, copy = false }: Props = {}) {
  const isEdit = journal !== undefined && !copy;
  const router = useRouter();

  const [date, setDate] = useState(copy ? localToday() : (journal?.journal_date ?? ""));
  const [from, setFrom] = useState<FromKey>(initialFrom(journal));
  const [toAccountId, setToAccountId] = useState(String(journal?.debits[0]?.account_id ?? ""));
  const [amount, setAmount] = useState(String(journal?.debits[0]?.amount ?? ""));
  const [description, setDescription] = useState(journal?.store_name ?? "");

  const [assetAccounts, setAssetAccounts] = useState<AssetAccount[]>([]);
  const [creditCards, setCreditCards] = useState<CreditCard[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    Promise.all([getAssetAccounts(), getCreditCards()])
      .then(([assets, cards]) => {
        if (cancelled) return;

        setAssetAccounts(assets);
        setCreditCards(cards);
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setError("口座・カードの取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [router]);

  const { fromType, fromId } = parseFrom(from);
  const fromAsset = fromType === "asset" ? assetAccounts.find((a) => a.id === fromId) : undefined;
  const toAsset = assetAccounts.find((a) => String(a.id) === toAccountId);

  // 出す元を変えて、選んでいた入れる先が選べなくなったら、選び直してもらう
  const changeFrom = (key: FromKey) => {
    setFrom(key);
    if (toAsset && !isAllowedTo(key, toAsset)) setToAccountId("");
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setError(null);

    const input = {
      journal_date: date,
      from_type: fromType,
      from_account_id: fromId,
      to_account_id: Number(toAccountId),
      amount: Number(amount),
      description: description.trim()
    };

    try {
      if (isEdit && journal) {
        await updateTransferJournal(journal.id, input);
        router.push("/journals");
        return;
      }

      await createTransferJournal(input);

      setStatus("success");
      setDate("");
      setFrom("");
      setToAccountId("");
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
        <label htmlFor="transfer-date" className={labelClass}>
          日付
        </label>
        <input
          id="transfer-date"
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="transfer-from" className={labelClass}>
          出す元
        </label>
        <select
          id="transfer-from"
          value={from}
          onChange={(e) => changeFrom(e.target.value as FromKey)}
          required
          className={inputClass}
        >
          <option value="">出す元を選択</option>
          {/* 立替金から返してもらうのは精算の画面で登録する（差額を費用・収益にできるように） */}
          {NON_RECEIVABLE_ASSET_TYPES.map((type) => (
            <optgroup key={type.value} label={type.label}>
              {assetAccounts
                .filter((account) => account.payment_method_type === type.value)
                .map((account) => (
                  <option key={account.id} value={`asset-${account.id}`}>
                    {account.name}
                  </option>
                ))}
            </optgroup>
          ))}
          <optgroup label="クレジットカード（電子マネーへのチャージ）">
            {creditCards.map((card) => (
              <option key={card.id} value={`card-${card.id}`}>
                {card.name}
              </option>
            ))}
          </optgroup>
        </select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="transfer-to" className={labelClass}>
          入れる先
        </label>
        <select
          id="transfer-to"
          value={toAccountId}
          onChange={(e) => setToAccountId(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">入れる先を選択</option>
          {ASSET_TYPES.map((type) => (
            <optgroup key={type.value} label={type.label}>
              {assetAccounts
                .filter((account) => account.payment_method_type === type.value && isAllowedTo(from, account))
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
        <label htmlFor="transfer-amount" className={labelClass}>
          金額
        </label>
        <div className="relative">
          <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-black/40 dark:text-white/40">
            ¥
          </span>
          <input
            id="transfer-amount"
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
        <label htmlFor="transfer-description" className={labelClass}>
          摘要（任意）
        </label>
        <input
          id="transfer-description"
          type="text"
          placeholder={`空なら「${autoLabel(fromType, fromAsset?.payment_method_type, toAsset?.payment_method_type)}」になります`}
          value={description}
          maxLength={MAX_DESCRIPTION_LENGTH}
          onChange={(e) => setDescription(e.target.value)}
          className={inputClass}
        />
      </div>

      {fromType === "credit_card" && from !== "" && (
        <p className="text-xs text-black/50 dark:text-white/50">
          カードからのチャージは、お買い物のカード払いと同じく、引き落とし日に預金から引き落とされます（通帳に予定として出ます）。
        </p>
      )}

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
