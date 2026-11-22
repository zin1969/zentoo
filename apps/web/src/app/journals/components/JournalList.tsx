"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import {
  deleteJournal,
  getJournals,
  isEditableJournal,
  isIncomeJournal,
  type Journal,
  type JournalPage
} from "@/lib/journals/journals";
import DirectDebitDateEditor from "./DirectDebitDateEditor";

type Loaded = {
  key: string;
  data?: JournalPage;
  error?: string;
};

function formatDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");

  return `${date.getFullYear()}-${month}-${day}`;
}

// 初期表示は当月（端末のローカル日付）
function currentMonthRange() {
  const now = new Date();

  return {
    from: formatDate(new Date(now.getFullYear(), now.getMonth(), 1)),
    to: formatDate(new Date(now.getFullYear(), now.getMonth() + 1, 0))
  };
}

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError && error.status === 422) {
    return error.data?.errors?.join(" / ") ?? "期間の指定が正しくありません。";
  }

  return "仕訳の取得に失敗しました。時間をおいて再度お試しください。";
}

function deleteErrorMessage(error: unknown) {
  if (error instanceof ApiError && error.status === 404) {
    return "この仕訳は見つかりませんでした。すでに削除されている可能性があります。";
  }

  if (error instanceof ApiError && error.data?.error === "direct_debit_journal_not_deletable") {
    return "引き落とし仕訳だけは削除できません。元のカード払いの仕訳を削除してください。";
  }

  return "仕訳の削除に失敗しました。時間をおいて再度お試しください。";
}

// 仕訳は DB から完全に消えるので、内容が分かる形で確認する
function deleteConfirmMessage(journal: Journal) {
  const total = journal.debits.reduce((sum, debit) => sum + debit.amount, 0);
  const lines = [
    "この仕訳を削除しますか？削除すると元に戻せません。",
    "",
    `${journal.journal_date} ${journal.store_name ?? ""} ${formatYen(total)}`
  ];

  if (journal.direct_debit_journal_id) {
    lines.push("", `カードの引き落とし仕訳（#${journal.direct_debit_journal_id}）も一緒に削除されます。`);
  }

  return lines.join("\n");
}

function DirectDebitBadge({ journal }: { journal: Journal }) {
  if (journal.original_journal_id) {
    return (
      <span className="rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-800 dark:bg-amber-900/30 dark:text-amber-300">
        カード引き落とし（元の仕訳 #{journal.original_journal_id}）
        {journal.payment_date_overridden && "・日付を変更済み"}
      </span>
    );
  }

  if (journal.direct_debit_journal_id) {
    return (
      <span className="rounded bg-blue-100 px-1.5 py-0.5 text-xs text-blue-800 dark:bg-blue-900/30 dark:text-blue-300">
        カード払い（引き落とし #{journal.direct_debit_journal_id}）
      </span>
    );
  }

  return null;
}

// お買い物と収入は、それぞれの修正画面で直す。それ以外の仕訳は、削除して登録し直す
function editHref(journal: Journal) {
  if (isEditableJournal(journal)) return `/journal-entries/${journal.id}/edit`;
  if (isIncomeJournal(journal)) return `/income-journals/${journal.id}/edit`;

  return null;
}

type JournalCardProps = {
  journal: Journal;
  deleting: boolean;
  onDelete: (journal: Journal) => void;
  onChanged: () => void;
};

function JournalCard({ journal, deleting, onDelete, onChanged }: JournalCardProps) {
  const href = editHref(journal);

  return (
    <li className="flex flex-col gap-2 rounded-xl border border-black/10 bg-white p-4 shadow-sm dark:border-white/10 dark:bg-black/20">
      <div className="flex items-baseline justify-between gap-2">
        <span className="text-sm font-medium text-foreground">{journal.journal_date}</span>
        <span className="min-w-0 truncate text-sm text-black/60 dark:text-white/60">
          {journal.store_name}
        </span>
      </div>

      <DirectDebitBadge journal={journal} />

      <div className="grid grid-cols-2 gap-3 text-sm">
        <div className="flex flex-col gap-1">
          <span className="text-xs text-black/50 dark:text-white/50">借方</span>
          {journal.debits.map((debit, i) => (
            <div key={i} className="flex flex-col">
              <span>{debit.account_name ?? "(不明な科目)"}</span>
              {debit.item_name && (
                <span className="text-xs text-black/50 dark:text-white/50">{debit.item_name}</span>
              )}
              <span className="text-right tabular-nums">{formatYen(debit.amount)}</span>
            </div>
          ))}
        </div>
        <div className="flex flex-col gap-1">
          <span className="text-xs text-black/50 dark:text-white/50">貸方</span>
          {journal.credits.map((credit, i) => (
            <div key={i} className="flex flex-col">
              <span>{credit.account_name ?? "(不明な科目)"}</span>
              <span className="text-right tabular-nums">{formatYen(credit.amount)}</span>
            </div>
          ))}
        </div>
      </div>

      {/* 引き落とし仕訳は自動で作られたものなので、日付だけを変えられる。修正・削除は元のカード払いの仕訳から */}
      {journal.original_journal_id !== null && (
        <DirectDebitDateEditor journal={journal} onChanged={onChanged} />
      )}

      {!journal.original_journal_id && (
        <div className="flex justify-end gap-2">
          {href && (
            <Link
              href={href}
              className="rounded-md border border-black/15 px-3 py-1.5 text-sm text-foreground dark:border-white/15"
            >
              修正
            </Link>
          )}
          <button
            type="button"
            disabled={deleting}
            onClick={() => onDelete(journal)}
            className="rounded-md border border-red-300 px-3 py-1.5 text-sm text-red-700 disabled:cursor-not-allowed disabled:opacity-40 dark:border-red-800 dark:text-red-300"
          >
            {deleting ? "削除中..." : "削除"}
          </button>
        </div>
      )}
    </li>
  );
}

export default function JournalList() {
  const router = useRouter();
  const [range, setRange] = useState(currentMonthRange);
  const [page, setPage] = useState(1);
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  // 削除や引き落とし日の変更のあとに、同じ期間・ページを読み直すための番号
  const [reloadCount, setReloadCount] = useState(0);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);

  const key = `${range.from}|${range.to}|${page}|${reloadCount}`;
  const loading = loaded?.key !== key;

  useEffect(() => {
    let cancelled = false;

    getJournals({ from: range.from, to: range.to, page })
      .then((data) => {
        if (!cancelled) setLoaded({ key, data });
      })
      .catch((error) => {
        if (cancelled) return;

        // 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する
        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
          return;
        }

        setLoaded({ key, error: errorMessage(error) });
      });

    return () => {
      cancelled = true;
    };
  }, [key, range.from, range.to, page, router]);

  const data = loaded?.key === key ? loaded.data : undefined;
  const totalPages = data ? Math.max(1, Math.ceil(data.total_count / data.per_page)) : 1;

  const handleDelete = async (journal: Journal) => {
    if (!window.confirm(deleteConfirmMessage(journal))) return;

    setDeletingId(journal.id);
    setDeleteError(null);

    try {
      await deleteJournal(journal.id);
      setReloadCount((n) => n + 1);
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }

      setDeleteError(deleteErrorMessage(error));
      // すでに削除されていた場合に備えて、一覧を最新にする
      setReloadCount((n) => n + 1);
    } finally {
      setDeletingId(null);
    }
  };

  const changeRange = (patch: Partial<typeof range>) => {
    setRange((current) => ({ ...current, ...patch }));
    setPage(1);
    setDeleteError(null);
  };

  const inputClass =
    "min-w-0 flex-1 rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";
  const pagerClass =
    "rounded-md border border-black/15 px-3 py-1.5 text-sm disabled:cursor-not-allowed disabled:opacity-40 dark:border-white/15";

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <input
          type="date"
          aria-label="開始日"
          value={range.from}
          onChange={(e) => changeRange({ from: e.target.value })}
          className={inputClass}
        />
        <span className="text-sm text-black/50 dark:text-white/50">〜</span>
        <input
          type="date"
          aria-label="終了日"
          value={range.to}
          onChange={(e) => changeRange({ to: e.target.value })}
          className={inputClass}
        />
      </div>

      {loaded?.key === key && loaded.error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {loaded.error}
        </p>
      )}

      {deleteError && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {deleteError}
        </p>
      )}

      {loading && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>}

      {data && (
        <>
          <p className="text-sm text-black/60 dark:text-white/60">{data.total_count} 件</p>

          {data.journals.length === 0 ? (
            <p className="rounded-xl border border-dashed border-black/15 px-4 py-8 text-center text-sm text-black/50 dark:border-white/15 dark:text-white/50">
              この期間の仕訳はありません。
            </p>
          ) : (
            <ul className="flex flex-col gap-3">
              {data.journals.map((journal) => (
                <JournalCard
                  key={journal.id}
                  journal={journal}
                  deleting={deletingId === journal.id}
                  onDelete={handleDelete}
                  onChanged={() => setReloadCount((n) => n + 1)}
                />
              ))}
            </ul>
          )}

          <div className="flex items-center justify-between">
            <button
              type="button"
              className={pagerClass}
              disabled={page <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              前へ
            </button>
            <span className="text-sm text-black/60 dark:text-white/60">
              {data.page} / {totalPages}
            </span>
            <button
              type="button"
              className={pagerClass}
              disabled={page >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              次へ
            </button>
          </div>
        </>
      )}
    </div>
  );
}
