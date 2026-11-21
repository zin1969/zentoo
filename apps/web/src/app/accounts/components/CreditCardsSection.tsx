"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getAssetAccounts, type AssetAccount } from "@/lib/masters/assetAccounts";
import {
  createCreditCard,
  deleteCreditCard,
  getCreditCards,
  updateCreditCard,
  type CreditCard,
  type CreditCardInput
} from "@/lib/masters/creditCards";
import {
  buttonClass,
  dangerButtonClass,
  errorClass,
  inputClass,
  noteClass,
  primaryButtonClass,
  sectionClass
} from "./styles";

const MAX_NAME_LENGTH = 50;
const DEPOSIT_ASSET_TYPE = 2;
const DAYS = Array.from({ length: 31 }, (_, i) => i + 1);

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "duplicate_account_name":
        return "同じ名前のカード（または借入）があります。";
      case "credit_card_in_use":
        return "仕訳で使っているため、削除できません。";
      case "bank_account_not_found":
        return "引き落とし口座が見つかりません。預金口座を選んでください。";
      case "credit_card_not_found":
        return "カードが見つかりません。画面を再読み込みしてください。";
    }

    if (error.data?.errors?.length) {
      return `名前（${MAX_NAME_LENGTH} 文字まで）、締め日、支払日、引き落とし口座を入力してください。`;
    }
  }

  return "保存に失敗しました。時間をおいて再度お試しください。";
}

function settingSummary(card: CreditCard) {
  if (card.cutoff_day === null || card.payment_day === null) return null;

  return `${card.cutoff_day} 日締め・${card.payment_day} 日払い・${card.bank_account_name ?? "(不明な口座)"}`;
}

type CardFormProps = {
  initial?: CreditCard;
  bankAccounts: AssetAccount[];
  submitLabel: string;
  busy: boolean;
  onSubmit: (input: CreditCardInput) => void;
  onCancel?: () => void;
};

function CardForm({ initial, bankAccounts, submitLabel, busy, onSubmit, onCancel }: CardFormProps) {
  const [name, setName] = useState(initial?.name ?? "");
  const [cutoffDay, setCutoffDay] = useState(String(initial?.cutoff_day ?? ""));
  const [paymentDay, setPaymentDay] = useState(String(initial?.payment_day ?? ""));
  const [bankAccountId, setBankAccountId] = useState(String(initial?.bank_account_id ?? ""));

  const isComplete = name.trim() && cutoffDay && paymentDay && bankAccountId;

  return (
    <form
      className="flex flex-col gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        onSubmit({
          name: name.trim(),
          cutoff_day: Number(cutoffDay),
          payment_day: Number(paymentDay),
          bank_account_id: Number(bankAccountId)
        });
      }}
    >
      <input
        type="text"
        aria-label="カードの名前"
        placeholder="カードの名前"
        value={name}
        maxLength={MAX_NAME_LENGTH}
        onChange={(e) => setName(e.target.value)}
        required
        className={inputClass}
      />
      <div className="flex items-center gap-2">
        <select
          aria-label="締め日"
          value={cutoffDay}
          onChange={(e) => setCutoffDay(e.target.value)}
          required
          className={`${inputClass} flex-1`}
        >
          <option value="">締め日</option>
          {DAYS.map((day) => (
            <option key={day} value={day}>
              {day} 日締め
            </option>
          ))}
        </select>
        <select
          aria-label="支払日"
          value={paymentDay}
          onChange={(e) => setPaymentDay(e.target.value)}
          required
          className={`${inputClass} flex-1`}
        >
          <option value="">支払日</option>
          {DAYS.map((day) => (
            <option key={day} value={day}>
              {day} 日払い
            </option>
          ))}
        </select>
      </div>
      <select
        aria-label="引き落とし口座"
        value={bankAccountId}
        onChange={(e) => setBankAccountId(e.target.value)}
        required
        className={inputClass}
      >
        <option value="">引き落とし口座を選択</option>
        {bankAccounts.map((account) => (
          <option key={account.id} value={account.id}>
            {account.name}
          </option>
        ))}
      </select>
      <div className="flex justify-end gap-2">
        {onCancel && (
          <button type="button" onClick={onCancel} disabled={busy} className={buttonClass}>
            やめる
          </button>
        )}
        <button type="submit" disabled={busy || !isComplete} className={primaryButtonClass}>
          {busy ? "保存中..." : submitLabel}
        </button>
      </div>
    </form>
  );
}

// クレジットカードと、その引き落とし設定（締め日・支払日・引き落とし口座）の一覧と、追加・変更・削除
export default function CreditCardsSection() {
  const router = useRouter();
  const [cards, setCards] = useState<CreditCard[] | null>(null);
  const [bankAccounts, setBankAccounts] = useState<AssetAccount[]>([]);
  const [reloadCount, setReloadCount] = useState(0);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // 追加フォームを、追加のたびに空に戻すための番号
  const [addFormKey, setAddFormKey] = useState(0);

  useEffect(() => {
    let cancelled = false;

    Promise.all([getCreditCards(), getAssetAccounts()])
      .then(([cardData, assetAccounts]) => {
        if (cancelled) return;

        setCards(cardData);
        // 引き落とし口座に選べるのは預金口座だけ
        setBankAccounts(assetAccounts.filter((account) => account.payment_method_type === DEPOSIT_ASSET_TYPE));
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setError("カードの取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [reloadCount, router]);

  // 保存・削除をして、成功したら一覧を読み直す
  const run = async (action: () => Promise<unknown>, onSuccess?: () => void) => {
    setBusy(true);
    setError(null);

    try {
      await action();
      onSuccess?.();
      setReloadCount((n) => n + 1);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }

      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  const remove = (card: CreditCard) => {
    if (!window.confirm(`カード「${card.name}」を削除しますか？`)) return;

    run(() => deleteCreditCard(card.id));
  };

  return (
    <section className={sectionClass}>
      <h2 className="text-base font-semibold text-foreground">クレジットカード</h2>

      {error && <p className={errorClass}>{error}</p>}

      {cards === null ? (
        !error && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>
      ) : (
        <ul className="flex flex-col divide-y divide-black/10 dark:divide-white/10">
          {cards.map((card) => (
            <li key={card.id} className="py-2.5">
              {editingId === card.id ? (
                <CardForm
                  initial={card}
                  bankAccounts={bankAccounts}
                  submitLabel="保存"
                  busy={busy}
                  onSubmit={(input) => run(() => updateCreditCard(card.id, input), () => setEditingId(null))}
                  onCancel={() => setEditingId(null)}
                />
              ) : (
                <div className="flex items-center gap-2">
                  <div className="flex min-w-0 flex-1 flex-col">
                    <span className="truncate text-sm text-foreground">{card.name}</span>
                    {settingSummary(card) ? (
                      <span className={noteClass}>
                        {settingSummary(card)}
                        {card.in_use && "・使用中"}
                      </span>
                    ) : (
                      <span className="text-xs text-amber-700 dark:text-amber-300">
                        引き落とし設定がありません。「変更」から登録してください。
                      </span>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setError(null);
                      setEditingId(card.id);
                    }}
                    disabled={busy}
                    className={buttonClass}
                  >
                    変更
                  </button>
                  {/* 使っているカードは、仕訳の一覧に「不明な科目」が出ないよう削除させない */}
                  <button
                    type="button"
                    onClick={() => remove(card)}
                    disabled={busy || card.in_use}
                    className={dangerButtonClass}
                  >
                    削除
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}

      <div className="flex flex-col gap-2 border-t border-black/10 pt-3 dark:border-white/10">
        <span className="text-sm font-medium text-foreground">カードを追加</span>
        <CardForm
          key={addFormKey}
          bankAccounts={bankAccounts}
          submitLabel="追加"
          busy={busy}
          onSubmit={(input) => run(() => createCreditCard(input), () => setAddFormKey((n) => n + 1))}
        />
        <p className={noteClass}>
          締め日・支払日を変えても、登録済みの引き落としの日付は変わりません（これから登録する分から使います）。月に無い日（31 日など）は月末として扱います。未払いの残高は「開始負債登録」で登録します。
        </p>
      </div>
    </section>
  );
}
