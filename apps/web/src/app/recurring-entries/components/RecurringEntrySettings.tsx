"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getAssetAccounts } from "@/lib/masters/assetAccounts";
import { getExpenseAccounts } from "@/lib/masters/expenseAccounts";
import { getLiabilityAccounts } from "@/lib/masters/liabilityAccounts";
import { getRevenueAccounts } from "@/lib/masters/revenueAccounts";
import {
  KIND_LABELS,
  createRecurringEntry,
  deleteRecurringEntry,
  getRecurringEntries,
  scheduleLabel,
  updateRecurringEntry,
  type RecurringEntry,
  type RecurringEntryInput
} from "@/lib/recurring/recurringEntries";
import { buttonClass, dangerButtonClass, errorClass, noteClass, primaryButtonClass, sectionClass } from "../../accounts/components/styles";
import RecurringEntryForm, { type Accounts } from "./RecurringEntryForm";

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "account_not_found":
        return "選んだ科目・口座が見つかりません。画面を再読み込みしてください。";
      case "recurring_entry_not_found":
        return "決まった収支が見つかりません。画面を再読み込みしてください。";
    }

    if (error.data?.errors?.length) {
      return error.data.errors.join(" / ");
    }
  }

  return "保存に失敗しました。時間をおいて再度お試しください。";
}

type Router = ReturnType<typeof useRouter>;

// 認証切れはログイン画面へ。それ以外は画面にメッセージを出す
function handleLoadError(e: unknown, router: Router, setError: (message: string) => void, message: string) {
  if (e instanceof ApiError && e.status === 401) {
    router.replace("/login");
    return;
  }

  setError(message);
}

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

// 決まった収支の一覧と、追加・変更・削除
export default function RecurringEntrySettings() {
  const router = useRouter();
  const [entries, setEntries] = useState<RecurringEntry[] | null>(null);
  const [accounts, setAccounts] = useState<Accounts | null>(null);
  const [reloadCount, setReloadCount] = useState(0);
  // 開いているフォーム。"new" は追加、数値は変更する決まった収支の ID
  const [editing, setEditing] = useState<"new" | number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    getRecurringEntries()
      .then((data) => {
        if (!cancelled) setEntries(data);
      })
      .catch((e) => {
        if (!cancelled) {
          handleLoadError(e, router, setError, "決まった収支の取得に失敗しました。時間をおいて再度お試しください。");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [reloadCount, router]);

  useEffect(() => {
    let cancelled = false;

    Promise.all([getExpenseAccounts(), getRevenueAccounts(), getAssetAccounts(), getLiabilityAccounts()])
      .then(([expense, revenue, asset, liability]) => {
        if (!cancelled) setAccounts({ expense, revenue, asset, liability });
      })
      .catch((e) => {
        if (!cancelled) {
          handleLoadError(e, router, setError, "科目・口座の取得に失敗しました。時間をおいて再度お試しください。");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [router]);

  // 保存・削除をして、成功したら一覧を読み直す
  const run = async (action: () => Promise<unknown>) => {
    setBusy(true);
    setError(null);

    try {
      await action();
      setEditing(null);
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

  const save = (input: RecurringEntryInput) =>
    run(() => (typeof editing === "number" ? updateRecurringEntry(editing, input) : createRecurringEntry(input)));

  const remove = (entry: RecurringEntry) => {
    if (!window.confirm(`「${entry.name}」を削除しますか？\n登録した仕訳は残ります。`)) return;

    run(() => deleteRecurringEntry(entry.id));
  };

  const open = (target: "new" | number) => {
    setError(null);
    setEditing(target);
  };

  const form = (entry?: RecurringEntry) =>
    accounts && (
      <RecurringEntryForm
        entry={entry}
        accounts={accounts}
        busy={busy}
        onSubmit={save}
        onCancel={() => setEditing(null)}
      />
    );

  return (
    <div className="flex flex-col gap-4">
      {error && <p className={errorClass}>{error}</p>}

      <section className={sectionClass}>
        {entries === null ? (
          !error && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>
        ) : entries.length === 0 ? (
          <p className={noteClass}>決まった収支はまだありません。</p>
        ) : (
          <ul className="flex flex-col divide-y divide-black/10 dark:divide-white/10">
            {entries.map((entry) => (
              <li key={entry.id} className="py-3">
                {editing === entry.id ? (
                  form(entry)
                ) : (
                  <div className="flex flex-col gap-2">
                    <div className="flex items-baseline justify-between gap-2">
                      <span className="truncate text-sm font-medium text-foreground">{entry.name}</span>
                      <span className="text-sm tabular-nums text-foreground">{formatYen(entry.amount)}</span>
                    </div>
                    <div className="flex flex-col gap-0.5">
                      <span className={noteClass}>
                        {KIND_LABELS[entry.kind]} · {scheduleLabel(entry)}
                        {entry.end_date ? ` · ${entry.end_date} まで` : ""}
                      </span>
                      {/* 支出は「費用科目 ← 支払い方法」、収入は「入金先 ← 収益科目」、振替は「入金先 ← 出金元」 */}
                      <span className={noteClass}>
                        {entry.debit_account_name ?? "?"} ← {entry.credit_account_name ?? "?"}
                      </span>
                      <span className={noteClass}>
                        {entry.next_date ? `次は ${entry.next_date}` : "終了しました"}
                      </span>
                    </div>
                    <div className="flex justify-end gap-2">
                      <button type="button" onClick={() => open(entry.id)} disabled={busy} className={buttonClass}>
                        変更
                      </button>
                      <button type="button" onClick={() => remove(entry)} disabled={busy} className={dangerButtonClass}>
                        削除
                      </button>
                    </div>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      {editing === "new" ? (
        <section className={sectionClass}>
          <h2 className="text-base font-semibold text-foreground">決まった収支を追加</h2>
          {form()}
        </section>
      ) : (
        <button type="button" onClick={() => open("new")} disabled={!accounts} className={primaryButtonClass}>
          決まった収支を追加
        </button>
      )}
    </div>
  );
}
