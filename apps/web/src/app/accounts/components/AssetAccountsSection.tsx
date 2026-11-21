"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import {
  ASSET_TYPES,
  createAssetAccount,
  deleteAssetAccount,
  getAssetAccounts,
  updateAssetAccount,
  type AssetAccount,
  type AssetAccountInput
} from "@/lib/masters/assetAccounts";

const MAX_NAME_LENGTH = 50;

function assetTypeLabel(value: number) {
  return ASSET_TYPES.find((type) => type.value === value)?.label ?? "不明";
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "duplicate_account_name":
        return "同じ名前の口座があります。";
      case "cash_account_already_exists":
        return "現金の口座は 1 つだけ登録できます。";
      case "asset_account_in_use":
        return "仕訳かカードの引き落とし口座で使っているため、削除や種別の変更はできません。";
      case "asset_account_not_found":
        return "口座が見つかりません。画面を再読み込みしてください。";
    }

    if (error.data?.errors?.length) {
      return `名前を入力してください（${MAX_NAME_LENGTH} 文字まで）。`;
    }
  }

  return "保存に失敗しました。時間をおいて再度お試しください。";
}

const inputClass =
  "min-w-0 rounded-md border border-black/15 px-2.5 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";
const buttonClass =
  "rounded-md border border-black/15 px-3 py-1.5 text-sm text-foreground disabled:cursor-not-allowed disabled:opacity-40 dark:border-white/15";
const primaryButtonClass =
  "rounded-md bg-blue-600 px-3 py-1.5 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60";

type AccountFormProps = {
  initial: AssetAccountInput;
  // 使われている口座は、種別を変えられない
  typeLocked?: boolean;
  submitLabel: string;
  busy: boolean;
  onSubmit: (input: AssetAccountInput) => void;
  onCancel?: () => void;
};

function AccountForm({ initial, typeLocked = false, submitLabel, busy, onSubmit, onCancel }: AccountFormProps) {
  const [name, setName] = useState(initial.name);
  const [assetType, setAssetType] = useState(initial.asset_type);

  return (
    <form
      className="flex flex-col gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        onSubmit({ name: name.trim(), asset_type: assetType });
      }}
    >
      <div className="flex items-center gap-2">
        <input
          type="text"
          aria-label="口座の名前"
          placeholder="口座の名前"
          value={name}
          maxLength={MAX_NAME_LENGTH}
          onChange={(e) => setName(e.target.value)}
          required
          className={`${inputClass} flex-1`}
        />
        <select
          aria-label="口座の種別"
          value={assetType}
          onChange={(e) => setAssetType(Number(e.target.value))}
          disabled={typeLocked}
          className={`${inputClass} w-28 shrink-0`}
        >
          {ASSET_TYPES.map((type) => (
            <option key={type.value} value={type.value}>
              {type.label}
            </option>
          ))}
        </select>
      </div>
      <div className="flex justify-end gap-2">
        {onCancel && (
          <button type="button" onClick={onCancel} disabled={busy} className={buttonClass}>
            やめる
          </button>
        )}
        <button type="submit" disabled={busy || !name.trim()} className={primaryButtonClass}>
          {busy ? "保存中..." : submitLabel}
        </button>
      </div>
    </form>
  );
}

// 口座（現金・預金・電子マネー）の一覧と、追加・変更・削除
export default function AssetAccountsSection() {
  const router = useRouter();
  const [accounts, setAccounts] = useState<AssetAccount[] | null>(null);
  const [reloadCount, setReloadCount] = useState(0);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // 追加フォームを、追加のたびに空に戻すための番号
  const [addFormKey, setAddFormKey] = useState(0);

  useEffect(() => {
    let cancelled = false;

    getAssetAccounts()
      .then((data) => {
        if (!cancelled) setAccounts(data);
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setError("口座の取得に失敗しました。時間をおいて再度お試しください。");
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

  const remove = (account: AssetAccount) => {
    if (!window.confirm(`口座「${account.name}」を削除しますか？`)) return;

    run(() => deleteAssetAccount(account.id));
  };

  return (
    <section className="flex flex-col gap-3 rounded-xl border border-black/10 bg-white p-4 shadow-sm dark:border-white/10 dark:bg-black/20">
      <h2 className="text-base font-semibold text-foreground">口座（現金・預金・電子マネー）</h2>

      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {error}
        </p>
      )}

      {accounts === null ? (
        !error && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>
      ) : (
        <ul className="flex flex-col divide-y divide-black/10 dark:divide-white/10">
          {accounts.map((account) => (
            <li key={account.id} className="py-2.5">
              {editingId === account.id ? (
                <AccountForm
                  initial={{ name: account.name, asset_type: account.payment_method_type }}
                  typeLocked={account.in_use}
                  submitLabel="保存"
                  busy={busy}
                  onSubmit={(input) =>
                    run(() => updateAssetAccount(account.id, input), () => setEditingId(null))
                  }
                  onCancel={() => setEditingId(null)}
                />
              ) : (
                <div className="flex items-center gap-2">
                  <div className="flex min-w-0 flex-1 flex-col">
                    <span className="truncate text-sm text-foreground">{account.name}</span>
                    <span className="text-xs text-black/50 dark:text-white/50">
                      {assetTypeLabel(account.payment_method_type)}
                      {account.in_use && "・使用中"}
                    </span>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setError(null);
                      setEditingId(account.id);
                    }}
                    disabled={busy}
                    className={buttonClass}
                  >
                    変更
                  </button>
                  {/* 使っている口座は、仕訳の一覧に「不明な科目」が出ないよう削除させない */}
                  <button
                    type="button"
                    onClick={() => remove(account)}
                    disabled={busy || account.in_use}
                    className="rounded-md border border-red-300 px-3 py-1.5 text-sm text-red-700 disabled:cursor-not-allowed disabled:opacity-40 dark:border-red-800 dark:text-red-300"
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
        <span className="text-sm font-medium text-foreground">口座を追加</span>
        <AccountForm
          key={addFormKey}
          initial={{ name: "", asset_type: 2 }}
          submitLabel="追加"
          busy={busy}
          onSubmit={(input) => run(() => createAssetAccount(input), () => setAddFormKey((n) => n + 1))}
        />
        <p className="text-xs text-black/50 dark:text-white/50">
          開始残高は「開始資産登録」で登録します。使っている口座は、名前だけ変えられます。
        </p>
      </div>
    </section>
  );
}
