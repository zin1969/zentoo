"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getJournal, isSettlementJournal, type Journal } from "@/lib/journals/journals";
import SettlementJournalForm from "./SettlementJournalForm";

type Loaded = {
  journal?: Journal;
  error?: string;
};

// 修正する精算の仕訳を取得してから、登録と同じフォームを、その内容で開く
export default function EditSettlementJournal({ journalId }: { journalId: string }) {
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
          isSettlementJournal(journal)
            ? { journal }
            : { error: "この仕訳は精算の仕訳ではないため、ここでは修正できません。" }
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
              ? "修正する仕訳が見つかりません。すでに削除されている可能性があります。"
              : "仕訳の取得に失敗しました。時間をおいて再度お試しください。"
        });
      });

    return () => {
      cancelled = true;
    };
  }, [isValidId, journalId, router]);

  const shown: Loaded | null = isValidId ? loaded : { error: "修正する仕訳が見つかりません。" };

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
      <p className="text-sm text-black/60 dark:text-white/60">修正すると、仕訳は新しい内容で作り直されます。</p>
      <SettlementJournalForm journal={shown.journal} />
    </div>
  );
}
