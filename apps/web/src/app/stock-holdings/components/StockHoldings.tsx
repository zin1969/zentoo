"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { localToday } from "@/lib/dates/localToday";
import {
  formatPrice,
  formatShares,
  getStockHoldings,
  type StockHoldings as StockHoldingsData
} from "@/lib/reports/stockHoldings";

type Loaded = {
  date: string;
  data?: StockHoldingsData;
  error?: string;
};

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError && error.status === 422) {
    return error.data?.errors?.join(" / ") ?? "日付の指定が正しくありません。";
  }

  return "保有株の取得に失敗しました。時間をおいて再度お試しください。";
}

// 銘柄ごとの株数・取得額・平均取得単価（基準日時点）
export default function StockHoldings() {
  const router = useRouter();
  const [date, setDate] = useState(localToday);
  const [loaded, setLoaded] = useState<Loaded | null>(null);

  const loading = loaded?.date !== date;

  useEffect(() => {
    // 入力途中（日付を消した状態）は取得しない
    if (!date) return;

    let cancelled = false;

    getStockHoldings(date)
      .then((data) => {
        if (!cancelled) setLoaded({ date, data });
      })
      .catch((error) => {
        if (cancelled) return;

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
  // 全部売った銘柄は、下にまとめて出す
  const held = data?.holdings.filter((h) => h.shares > 0) ?? [];
  const soldOut = data?.holdings.filter((h) => h.shares <= 0) ?? [];

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
            <span className="text-xs text-black/50 dark:text-white/50">取得額の合計</span>
            <span className="text-2xl font-semibold tabular-nums">{formatYen(data.total_cost)}</span>
          </div>

          {held.length === 0 && (
            <p className="text-sm text-black/50 dark:text-white/50">
              持っている株はありません。今持っている株は「開始資産登録」で、株数と平均取得単価で登録します。
            </p>
          )}

          {held.length > 0 && (
            <ul className="flex flex-col divide-y divide-black/10 rounded-xl border border-black/10 bg-white shadow-sm dark:divide-white/10 dark:border-white/10 dark:bg-black/20">
              {held.map((holding) => (
                <li key={holding.account_id} className="flex flex-col gap-1 px-4 py-3">
                  <div className="flex items-baseline justify-between gap-2">
                    <span className="min-w-0 truncate text-sm font-medium">{holding.account_name}</span>
                    <span className="tabular-nums">{formatYen(holding.cost)}</span>
                  </div>
                  <div className="flex items-baseline justify-between gap-2 text-xs text-black/50 dark:text-white/50">
                    <span className="tabular-nums">{formatShares(holding.shares)}</span>
                    {holding.average_price !== null && (
                      <span className="tabular-nums">平均取得単価 {formatPrice(holding.average_price)}</span>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          )}

          {soldOut.length > 0 && (
            <section className="flex flex-col gap-2">
              <h2 className="text-sm font-medium text-black/60 dark:text-white/60">全部売った銘柄</h2>
              <ul className="flex flex-col divide-y divide-black/10 rounded-xl border border-black/10 bg-white text-sm text-black/60 shadow-sm dark:divide-white/10 dark:border-white/10 dark:bg-black/20 dark:text-white/60">
                {soldOut.map((holding) => (
                  <li key={holding.account_id} className="px-4 py-3">
                    {holding.account_name}
                  </li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </div>
  );
}
