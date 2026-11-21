"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import {
  createExpenseAccount,
  deleteExpenseAccount,
  getExpenseAccounts,
  updateExpenseAccount,
  type ExpenseAccount,
  type ExpenseAccountInput
} from "@/lib/masters/expenseAccounts";
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

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "duplicate_account_name":
        return "同じ親の中に、同じ名前の科目があります。";
      case "expense_account_in_use":
        return "仕訳で使っているため、削除や親の変更はできません。";
      case "expense_account_has_children":
        return "子科目があるため、削除や親の設定はできません。";
      case "invalid_parent":
        return "親にできるのは、親の無い科目だけです。";
      case "expense_account_not_found":
        return "科目が見つかりません。画面を再読み込みしてください。";
    }

    if (error.data?.errors?.length) {
      return `名前を入力してください（${MAX_NAME_LENGTH} 文字まで）。`;
    }
  }

  return "保存に失敗しました。時間をおいて再度お試しください。";
}

// 親の科目の直後に、その子科目を並べる
function inTreeOrder(accounts: ExpenseAccount[]) {
  const ids = new Set(accounts.map((account) => account.id));
  const tops = accounts.filter((account) => account.parent_id === null || !ids.has(account.parent_id));

  return tops.flatMap((top) => [
    { account: top, depth: 0 },
    ...accounts.filter((account) => account.parent_id === top.id).map((account) => ({ account, depth: 1 }))
  ]);
}

type AccountFormProps = {
  initial: ExpenseAccountInput;
  // 親にできる科目（親の無い科目。変更のときは自分自身を除く）
  parents: ExpenseAccount[];
  // 使われている科目や子科目のある科目は、親を変えられない
  parentLocked?: boolean;
  submitLabel: string;
  busy: boolean;
  onSubmit: (input: ExpenseAccountInput) => void;
  onCancel?: () => void;
};

function AccountForm({ initial, parents, parentLocked = false, submitLabel, busy, onSubmit, onCancel }: AccountFormProps) {
  const [name, setName] = useState(initial.name);
  const [parentId, setParentId] = useState(initial.parent_id === null ? "" : String(initial.parent_id));

  return (
    <form
      className="flex flex-col gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        onSubmit({ name: name.trim(), parent_id: parentId === "" ? null : Number(parentId) });
      }}
    >
      <div className="flex items-center gap-2">
        <input
          type="text"
          aria-label="科目の名前"
          placeholder="科目の名前"
          value={name}
          maxLength={MAX_NAME_LENGTH}
          onChange={(e) => setName(e.target.value)}
          required
          className={`${inputClass} flex-1`}
        />
        <select
          aria-label="親の科目"
          value={parentId}
          onChange={(e) => setParentId(e.target.value)}
          disabled={parentLocked}
          className={`${inputClass} w-32 shrink-0`}
        >
          <option value="">親なし</option>
          {parents.map((parent) => (
            <option key={parent.id} value={parent.id}>
              {parent.name} の下
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

// 費用科目（全ユーザー共通、親子の 2 階層）の一覧と、追加・変更・削除
export default function ExpenseAccountsSection() {
  const router = useRouter();
  const [accounts, setAccounts] = useState<ExpenseAccount[] | null>(null);
  const [reloadCount, setReloadCount] = useState(0);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // 追加フォームを、追加のたびに空に戻すための番号
  const [addFormKey, setAddFormKey] = useState(0);

  useEffect(() => {
    let cancelled = false;

    getExpenseAccounts()
      .then((data) => {
        if (!cancelled) setAccounts(data);
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setError("費用科目の取得に失敗しました。時間をおいて再度お試しください。");
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

  const remove = (account: ExpenseAccount) => {
    if (!window.confirm(`費用科目「${account.name}」を削除しますか？`)) return;

    run(() => deleteExpenseAccount(account.id));
  };

  const topLevel = (accounts ?? []).filter((account) => account.parent_id === null);

  return (
    <section className={sectionClass}>
      <h2 className="text-base font-semibold text-foreground">費用科目</h2>

      {error && <p className={errorClass}>{error}</p>}

      {accounts === null ? (
        !error && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>
      ) : (
        <ul className="flex flex-col divide-y divide-black/10 dark:divide-white/10">
          {inTreeOrder(accounts).map(({ account, depth }) => (
            <li key={account.id} className={depth === 1 ? "py-2.5 pl-5" : "py-2.5"}>
              {editingId === account.id ? (
                <AccountForm
                  initial={{ name: account.name, parent_id: account.parent_id }}
                  parents={topLevel.filter((parent) => parent.id !== account.id)}
                  parentLocked={account.in_use || account.has_children}
                  submitLabel="保存"
                  busy={busy}
                  onSubmit={(input) =>
                    run(() => updateExpenseAccount(account.id, input), () => setEditingId(null))
                  }
                  onCancel={() => setEditingId(null)}
                />
              ) : (
                <div className="flex items-center gap-2">
                  <div className="flex min-w-0 flex-1 flex-col">
                    <span className="truncate text-sm text-foreground">
                      {depth === 1 && <span className="text-black/40 dark:text-white/40">└ </span>}
                      {account.name}
                    </span>
                    {account.in_use && <span className={noteClass}>使用中</span>}
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
                  {/* 使っている科目は、仕訳の一覧と月次の支出から抜けないよう削除させない */}
                  <button
                    type="button"
                    onClick={() => remove(account)}
                    disabled={busy || account.in_use || account.has_children}
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
        <span className="text-sm font-medium text-foreground">費用科目を追加</span>
        <AccountForm
          key={addFormKey}
          initial={{ name: "", parent_id: null }}
          parents={topLevel}
          submitLabel="追加"
          busy={busy}
          onSubmit={(input) => run(() => createExpenseAccount(input), () => setAddFormKey((n) => n + 1))}
        />
        <p className={noteClass}>
          費用科目は全員で共通です。使っている科目は名前だけ変えられます。子科目のある科目は削除できません。
        </p>
      </div>
    </section>
  );
}
