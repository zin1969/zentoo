"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { updateDirectDebitDate, type Journal } from "@/lib/journals/journals";

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    if (error.data?.error === "payment_date_before_journal_date") {
      return "買った日より前の日付にはできません。";
    }

    if (error.status === 404) {
      return "この仕訳は見つかりませんでした。すでに削除されている可能性があります。";
    }

    if (error.data?.errors?.length) {
      return "日付を入力してください。";
    }
  }

  return "引き落とし日の変更に失敗しました。時間をおいて再度お試しください。";
}

type Props = {
  // 引き落とし仕訳
  journal: Journal;
  onChanged: () => void;
};

// 締め日の近くで買うと引き落としが翌月になることがあるので、カードの明細の日付に合わせて直す
export default function DirectDebitDateEditor({ journal, onChanged }: Props) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [paymentDate, setPaymentDate] = useState(journal.journal_date);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 一覧を読み直したあとも、開くたびに今の引き落とし日から始める
  const open = () => {
    setPaymentDate(journal.journal_date);
    setError(null);
    setEditing(true);
  };

  const cancel = () => {
    setEditing(false);
    setPaymentDate(journal.journal_date);
    setError(null);
  };

  const save = async () => {
    setSaving(true);
    setError(null);

    try {
      await updateDirectDebitDate(journal.id, paymentDate);
      setEditing(false);
      onChanged();
    } catch (e) {
      // 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }

      setError(errorMessage(e));
    } finally {
      setSaving(false);
    }
  };

  const buttonClass =
    "rounded-md border border-black/15 px-3 py-1.5 text-sm text-foreground disabled:cursor-not-allowed disabled:opacity-40 dark:border-white/15";

  if (!editing) {
    return (
      <div className="flex justify-end">
        <button type="button" onClick={open} className={buttonClass}>
          引き落とし日を変更
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {error}
        </p>
      )}
      <div className="flex items-center gap-2">
        <input
          type="date"
          aria-label="新しい引き落とし日"
          value={paymentDate}
          onChange={(e) => setPaymentDate(e.target.value)}
          className="min-w-0 flex-1 rounded-md border border-black/15 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20"
        />
        <button type="button" onClick={cancel} disabled={saving} className={buttonClass}>
          やめる
        </button>
        <button
          type="button"
          onClick={save}
          disabled={saving || !paymentDate || paymentDate === journal.journal_date}
          className="rounded-md bg-blue-600 px-3 py-1.5 text-sm font-medium text-white disabled:cursor-not-allowed disabled:opacity-60"
        >
          {saving ? "保存中..." : "保存"}
        </button>
      </div>
      <p className="text-xs text-black/50 dark:text-white/50">
        カードの明細の引き落とし日を入れてください。土日・祝日でも、そのままの日付で登録します。
      </p>
    </div>
  );
}
