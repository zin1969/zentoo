"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import {
  getMonthlyExpenses,
  type MonthlyExpense,
  type MonthlyExpenses as MonthlyExpensesData
} from "@/lib/reports/monthlyExpenses";

type Loaded = {
  month: string;
  data?: MonthlyExpensesData;
  error?: string;
};

// 端末のローカル日付の月（YYYY-MM）
function currentMonth() {
  const now = new Date();

  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
}

// YYYY-MM を months か月ずらす
function shiftMonth(month: string, months: number) {
  const [year, mon] = month.split("-").map(Number);
  const shifted = new Date(year, mon - 1 + months, 1);

  return `${shifted.getFullYear()}-${String(shifted.getMonth() + 1).padStart(2, "0")}`;
}

function formatMonth(month: string) {
  const [year, mon] = month.split("-").map(Number);

  return `${year}年${mon}月`;
}

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError && error.status === 422) {
    return error.data?.errors?.join(" / ") ?? "月の指定が正しくありません。";
  }

  return "支出の取得に失敗しました。時間をおいて再度お試しください。";
}

type AmountListProps = {
  title: string;
  total: number;
  items: MonthlyExpense[];
  emptyText: string;
};

// 科目ごとの金額の一覧と、その合計（収入・支出で共通）
function AmountList({ title, total, items, emptyText }: AmountListProps) {
  return (
    <section className="flex flex-col gap-2">
      <div className="flex items-baseline justify-between px-1">
        <h2 className="text-sm font-medium text-foreground">{title}</h2>
        <span className="text-base font-semibold tabular-nums">{formatYen(total)}</span>
      </div>

      {items.length === 0 ? (
        <p className="rounded-xl border border-dashed border-black/15 px-4 py-6 text-center text-sm text-black/50 dark:border-white/15 dark:text-white/50">
          {emptyText}
        </p>
      ) : (
        <ul className="flex flex-col divide-y divide-black/10 rounded-xl border border-black/10 bg-white shadow-sm dark:divide-white/10 dark:border-white/10 dark:bg-black/20">
          {items.map((item) => (
            <li key={item.account_id} className="flex items-baseline justify-between gap-2 px-4 py-3">
              <span className="min-w-0 truncate text-sm">{item.account_name}</span>
              <span className="tabular-nums">{formatYen(item.amount)}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

export default function MonthlyExpenses() {
  const router = useRouter();
  const [month, setMonth] = useState(currentMonth);
  const [loaded, setLoaded] = useState<Loaded | null>(null);

  const loading = loaded?.month !== month;

  useEffect(() => {
    let cancelled = false;

    getMonthlyExpenses(month)
      .then((data) => {
        if (!cancelled) setLoaded({ month, data });
      })
      .catch((error) => {
        if (cancelled) return;

        // 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する
        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
          return;
        }

        setLoaded({ month, error: errorMessage(error) });
      });

    return () => {
      cancelled = true;
    };
  }, [month, router]);

  const data = loaded?.month === month ? loaded.data : undefined;

  const buttonClass =
    "rounded-md border border-black/15 px-3 py-1.5 text-sm dark:border-white/15";

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <button type="button" className={buttonClass} onClick={() => setMonth((m) => shiftMonth(m, -1))}>
          前月
        </button>
        <span className="text-base font-medium">{formatMonth(month)}</span>
        <button type="button" className={buttonClass} onClick={() => setMonth((m) => shiftMonth(m, 1))}>
          翌月
        </button>
      </div>

      {loaded?.month === month && loaded.error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {loaded.error}
        </p>
      )}

      {loading && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>}

      {data && (
        <>
          {/* 収支（収入 − 支出）。マイナスは赤字 */}
          <div className="flex flex-col gap-1 rounded-xl border border-black/10 bg-white px-4 py-4 shadow-sm dark:border-white/10 dark:bg-black/20">
            <span className="text-xs text-black/50 dark:text-white/50">収支（収入 − 支出）</span>
            <span
              className={`text-2xl font-semibold tabular-nums ${data.net < 0 ? "text-red-700 dark:text-red-300" : ""}`}
            >
              {formatYen(data.net)}
            </span>
          </div>

          <AmountList title="収入" total={data.income_total} items={data.income_items} emptyText="この月の収入はありません。" />
          <AmountList title="支出" total={data.total} items={data.items} emptyText="この月の支出はありません。" />
        </>
      )}
    </div>
  );
}
