"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { localToday } from "@/lib/dates/localToday";
import {
  PERIODS,
  PERIOD_WEEK,
  TARGET_EXPENSE_ACCOUNT,
  getBudgetReport,
  type BudgetReport,
  type BudgetReportItem
} from "@/lib/budgets/budgets";
import { elapsedRatio, periodLabel, shiftPeriod } from "@/lib/budgets/periods";

const EXPENSE_ELEMENT_TYPE = 5;

type Loaded = {
  date: string;
  data?: BudgetReport;
  error?: string;
};

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

// 予算の対象と期間で絞った仕訳一覧。除くタグは仕訳一覧では外せないので、その分も出る
function journalsHref(item: BudgetReportItem) {
  const params = new URLSearchParams({ from: item.period_start, to: item.period_end });
  if (item.target_type === TARGET_EXPENSE_ACCOUNT) {
    params.set("account", `${EXPENSE_ELEMENT_TYPE}:${item.expense_account_id}`);
  } else {
    params.set("tag", String(item.tag_id));
  }

  return `/journals?${params}`;
}

function BudgetCard({ item, today }: { item: BudgetReportItem; today: string }) {
  const ratio = elapsedRatio(item.period_start, item.period_end, today);
  // 今日が期間の中にあるときだけ、今日までの目安を出す
  const inProgress = ratio > 0 && ratio < 1;
  const pace = Math.round(item.budget_amount * ratio);
  const usedRatio = item.budget_amount > 0 ? item.used_amount / item.budget_amount : item.used_amount > 0 ? 1 : 0;
  const over = item.remaining_amount < 0;
  const aheadOfPace = inProgress && item.used_amount > pace;
  const barColor = over ? "bg-red-500" : aheadOfPace ? "bg-amber-500" : "bg-blue-500";

  return (
    <li>
      <Link
        href={journalsHref(item)}
        className="flex flex-col gap-2 rounded-xl border border-black/10 bg-white px-4 py-3 shadow-sm transition-colors hover:border-blue-500 dark:border-white/10 dark:bg-black/20"
      >
        <div className="flex items-baseline justify-between gap-2">
          <span className="min-w-0 truncate text-sm font-medium">{item.name}</span>
          <span className={`shrink-0 text-sm tabular-nums ${over ? "font-medium text-red-600 dark:text-red-400" : ""}`}>
            {over ? `${formatYen(-item.remaining_amount)} 超過` : `残り ${formatYen(item.remaining_amount)}`}
          </span>
        </div>

        <div className="relative h-2.5 overflow-hidden rounded-full bg-black/10 dark:bg-white/10">
          <div className={`h-full ${barColor}`} style={{ width: `${Math.min(usedRatio, 1) * 100}%` }} />
          {inProgress && (
            <div
              className="absolute inset-y-0 w-0.5 bg-black/60 dark:bg-white/70"
              style={{ left: `${ratio * 100}%` }}
              aria-hidden="true"
            />
          )}
        </div>

        <div className="flex items-baseline justify-between gap-2 text-xs text-black/55 dark:text-white/55">
          <span className="tabular-nums">
            {formatYen(item.used_amount)} / {formatYen(item.budget_amount)}
          </span>
          {inProgress && <span className="tabular-nums">今日までの目安 {formatYen(pace)}</span>}
        </div>

        <span className="text-xs text-black/45 dark:text-white/45">
          {item.target_type === TARGET_EXPENSE_ACCOUNT ? "科目" : "タグ"}: {item.target_name}
          {item.excluded_tags.length > 0 && `（除く: ${item.excluded_tags.map((tag) => tag.name).join("・")}）`}
        </span>
      </Link>
    </li>
  );
}

// 予算ごとの、今週・今月・今年（前の期間にも切り替えられる）の予算と使った額
export default function BudgetReportView() {
  const router = useRouter();
  const [today] = useState(localToday);
  const [periodType, setPeriodType] = useState<number>(PERIOD_WEEK);
  // 周期ごとに見ている日付（その日を含む期間を出す）
  const [dates, setDates] = useState<Record<number, string>>(() =>
    Object.fromEntries(PERIODS.map((period) => [period.value, today]))
  );
  const [loaded, setLoaded] = useState<Loaded | null>(null);

  const date = dates[periodType];
  const loading = loaded?.date !== date;

  useEffect(() => {
    let cancelled = false;

    getBudgetReport(date)
      .then((data) => {
        if (!cancelled) setLoaded({ date, data });
      })
      .catch((error) => {
        if (cancelled) return;

        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
          return;
        }

        setLoaded({ date, error: "予算の取得に失敗しました。時間をおいて再度お試しください。" });
      });

    return () => {
      cancelled = true;
    };
  }, [date, router]);

  const data = loaded?.date === date ? loaded.data : undefined;
  const items = data?.budgets.filter((item) => item.period_type === periodType) ?? [];
  const period = PERIODS.find((p) => p.value === periodType) ?? PERIODS[0];
  const first = items[0];
  const isCurrent = first ? first.period_start <= today && today <= first.period_end : date === today;

  const move = (step: number) => {
    setDates((current) => ({ ...current, [periodType]: shiftPeriod(current[periodType], periodType, step) }));
  };

  const backToCurrent = () => setDates((current) => ({ ...current, [periodType]: today }));

  const pagerClass = "rounded-md border border-black/15 px-3 py-1.5 text-sm dark:border-white/15";

  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-3 gap-1 rounded-lg bg-black/5 p-1 dark:bg-white/10" role="tablist">
        {PERIODS.map((p) => (
          <button
            key={p.value}
            type="button"
            role="tab"
            aria-selected={periodType === p.value}
            onClick={() => setPeriodType(p.value)}
            className={
              periodType === p.value
                ? "rounded-md bg-white px-3 py-1.5 text-sm font-medium text-foreground shadow-sm dark:bg-black/40"
                : "rounded-md px-3 py-1.5 text-sm text-black/60 dark:text-white/60"
            }
          >
            {p.label}
          </button>
        ))}
      </div>

      <div className="flex items-center justify-between gap-2">
        <button type="button" className={pagerClass} onClick={() => move(-1)}>
          前へ
        </button>
        <div className="flex min-w-0 flex-col items-center">
          <span className="truncate text-sm font-medium">
            {first ? periodLabel(periodType, first.period_start, first.period_end) : period.current}
          </span>
          {!isCurrent && (
            <button type="button" onClick={backToCurrent} className="text-xs text-blue-600 underline dark:text-blue-400">
              {period.current}に戻る
            </button>
          )}
        </div>
        <button type="button" className={pagerClass} onClick={() => move(1)}>
          次へ
        </button>
      </div>

      {loaded?.date === date && loaded.error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {loaded.error}
        </p>
      )}

      {loading && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>}

      {data && items.length === 0 && (
        <p className="rounded-xl border border-dashed border-black/15 px-4 py-8 text-center text-sm text-black/50 dark:border-white/15 dark:text-white/50">
          {period.label}の予算はありません。
          <Link href="/budgets/settings" className="ml-1 text-blue-600 underline dark:text-blue-400">
            予算の設定
          </Link>
          で追加できます。
        </p>
      )}

      {items.length > 0 && (
        <>
          <ul className="flex flex-col gap-3">
            {items.map((item) => (
              <BudgetCard key={item.id} item={item} today={today} />
            ))}
          </ul>
          <p className="text-xs text-black/50 dark:text-white/50">
            使った額は、期間の中の日付（買った日）の支出の合計です。棒の縦線は今日までの目安で、目安より多く使っていると黄色になります。
            予算をタップすると、その期間の仕訳一覧を開きます（除くタグの分も一覧には出ます）。
          </p>
        </>
      )}
    </div>
  );
}
