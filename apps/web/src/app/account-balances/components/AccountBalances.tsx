"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import {
  getAccountBalances,
  type AccountBalance,
  type AccountBalances as AccountBalancesData
} from "@/lib/reports/accountBalances";

type Loaded = {
  date: string;
  data?: AccountBalancesData;
  error?: string;
};

// 端末のローカル日付（YYYY-MM-DD）
function today() {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");

  return `${now.getFullYear()}-${month}-${day}`;
}

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError && error.status === 422) {
    return error.data?.errors?.join(" / ") ?? "日付の指定が正しくありません。";
  }

  return "残高の取得に失敗しました。時間をおいて再度お試しください。";
}

function Section({ title, accounts, total }: { title: string; accounts: AccountBalance[]; total: number }) {
  return (
    <section className="flex flex-col gap-2">
      <h2 className="text-sm font-medium text-black/60 dark:text-white/60">{title}</h2>
      <ul className="flex flex-col divide-y divide-black/10 rounded-xl border border-black/10 bg-white shadow-sm dark:divide-white/10 dark:border-white/10 dark:bg-black/20">
        {accounts.length === 0 && (
          <li className="px-4 py-3 text-sm text-black/50 dark:text-white/50">科目がありません。</li>
        )}
        {accounts.map((account) => (
          <li key={account.account_id} className="flex items-baseline justify-between gap-2 px-4 py-3">
            <span className="min-w-0 truncate text-sm">{account.account_name}</span>
            <span className="tabular-nums">{formatYen(account.balance)}</span>
          </li>
        ))}
        <li className="flex items-baseline justify-between gap-2 px-4 py-3 font-medium">
          <span className="text-sm">合計</span>
          <span className="tabular-nums">{formatYen(total)}</span>
        </li>
      </ul>
    </section>
  );
}

export default function AccountBalances() {
  const router = useRouter();
  const [date, setDate] = useState(today);
  const [loaded, setLoaded] = useState<Loaded | null>(null);

  const loading = loaded?.date !== date;

  useEffect(() => {
    // 入力途中（日付を消した状態）は取得しない
    if (!date) return;

    let cancelled = false;

    getAccountBalances(date)
      .then((data) => {
        if (!cancelled) setLoaded({ date, data });
      })
      .catch((error) => {
        if (cancelled) return;

        // 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する
        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
          return;
        }

        setLoaded({ date, error: errorMessage(error) });
      });

    return () => {
      cancelled = true;
    };
  }, [date, router]);

  const data = loaded?.date === date ? loaded.data : undefined;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <input
          type="date"
          aria-label="基準日"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          className="min-w-0 flex-1 rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20"
        />
        <span className="text-sm text-black/50 dark:text-white/50">時点</span>
      </div>

      {loaded?.date === date && loaded.error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {loaded.error}
        </p>
      )}

      {loading && date && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>}

      {data && (
        <>
          <div className="flex flex-col gap-1 rounded-xl border border-black/10 bg-white px-4 py-4 shadow-sm dark:border-white/10 dark:bg-black/20">
            <span className="text-xs text-black/50 dark:text-white/50">純資産（資産 − 負債）</span>
            <span className="text-2xl font-semibold tabular-nums">{formatYen(data.net_assets)}</span>
          </div>

          <Section title="資産" accounts={data.assets} total={data.total_assets} />
          <Section title="負債（カードの未払いなど）" accounts={data.liabilities} total={data.total_liabilities} />
        </>
      )}
    </div>
  );
}
