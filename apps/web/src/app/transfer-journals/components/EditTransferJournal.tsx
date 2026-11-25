"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getJournal, isTransferJournal, type Journal } from "@/lib/journals/journals";
import TransferJournalForm from "./TransferJournalForm";

type Loaded = {
  journal?: Journal;
  error?: string;
};

// 修正する振替の仕訳を取得してから、登録と同じフォームを、その内容で開く。
// copy のときは、その内容をコピーした新しい登録として開く（日付は今日。元の仕訳は変えない）
export default function EditTransferJournal({ journalId, copy = false }: { journalId: string; copy?: boolean }) {
  const router = useRouter();
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  const isValidId = /^\d+$/.test(journalId);

  useEffect(() => {
    if (!isValidId) return;

    let cancelled = false;

    getJournal(Number(journalId))
      .then((journal) => {
        if (cancelled) return;

        setLoaded(
          isTransferJournal(journal)
            ? { journal }
            : { error: copy ? "この仕訳は振替の仕訳ではないため、ここではコピーできません。" : "この仕訳は振替の仕訳ではないため、ここでは修正できません。" }
        );
      })
      .catch((error) => {
        if (cancelled) return;

        // 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する
        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
          return;
        }

        setLoaded({
          error:
            error instanceof ApiError && error.status === 404
              ? `${copy ? "コピー" : "修正"}する仕訳が見つかりません。すでに削除されている可能性があります。`
              : "仕訳の取得に失敗しました。時間をおいて再度お試しください。"
        });
      });

    return () => {
      cancelled = true;
    };
  }, [copy, isValidId, journalId, router]);

  const shown: Loaded | null = isValidId
    ? loaded
    : { error: `${copy ? "コピー" : "修正"}する仕訳が見つかりません。` };

  if (!shown) {
    return <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>;
  }

  if (!shown.journal) {
    return (
      <div className="flex flex-col gap-3">
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {shown.error}
        </p>
        <Link href="/journals" className="text-sm font-medium text-blue-600 hover:text-blue-700">
          仕訳一覧に戻る
        </Link>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-black/60 dark:text-white/60">
        {copy
          ? "コピーした内容で、新しく登録します（日付は今日）。違うところを直してから登録してください。"
          : "修正すると、仕訳は新しい内容で作り直されます。カードからのチャージは、引き落とし仕訳も作り直します。"}
      </p>
      <TransferJournalForm journal={shown.journal} copy={copy} />
    </div>
  );
}
