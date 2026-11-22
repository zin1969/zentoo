"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getTags, type Tag } from "@/lib/masters/tags";
import { getTagReport, getTagReportItems, type TagReport, type TagReportItems } from "@/lib/reports/tagReports";

type Loaded<T> = {
  key: string;
  data?: T;
  error?: string;
};

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

// 認証切れ（BFF がトークン Cookie を破棄済み）の場合は、ログイン画面へ誘導する
function isUnauthorized(error: unknown) {
  return error instanceof ApiError && error.status === 401;
}

function errorMessage(error: unknown, what: string) {
  if (error instanceof ApiError && error.status === 404) {
    return "タグが見つかりません。画面を再読み込みしてください。";
  }

  return `${what}の取得に失敗しました。時間をおいて再度お試しください。`;
}

const errorClass = "rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300";
const mutedClass = "text-sm text-black/50 dark:text-white/50";

// タグを選ぶと、1 年分の支出を月ごとに出す。月をタップすると、その月の明細を開く
export default function TagReportView() {
  const router = useRouter();
  const [tags, setTags] = useState<Tag[] | null>(null);
  const [tagId, setTagId] = useState<number | null>(null);
  const [year, setYear] = useState(() => new Date().getFullYear());
  const [openMonth, setOpenMonth] = useState<number | null>(null);
  const [report, setReport] = useState<Loaded<TagReport> | null>(null);
  const [monthItems, setMonthItems] = useState<Loaded<TagReportItems> | null>(null);
  const [tagError, setTagError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    getTags()
      .then((data) => {
        if (cancelled) return;

        setTags(data);
        setTagId((current) => current ?? data[0]?.id ?? null);
      })
      .catch((e) => {
        if (cancelled) return;
        if (isUnauthorized(e)) return router.replace("/login");

        setTagError("タグの取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [router]);

  const reportKey = `${tagId}|${year}`;

  useEffect(() => {
    if (tagId === null) return;

    let cancelled = false;

    getTagReport(tagId, year)
      .then((data) => {
        if (!cancelled) setReport({ key: reportKey, data });
      })
      .catch((e) => {
        if (cancelled) return;
        if (isUnauthorized(e)) return router.replace("/login");

        setReport({ key: reportKey, error: errorMessage(e, "集計") });
      });

    return () => {
      cancelled = true;
    };
  }, [reportKey, tagId, year, router]);

  const monthKey = `${tagId}|${year}|${openMonth}`;

  useEffect(() => {
    if (tagId === null || openMonth === null) return;

    let cancelled = false;
    const month = `${year}-${String(openMonth).padStart(2, "0")}`;

    getTagReportItems(tagId, month)
      .then((data) => {
        if (!cancelled) setMonthItems({ key: monthKey, data });
      })
      .catch((e) => {
        if (cancelled) return;
        if (isUnauthorized(e)) return router.replace("/login");

        setMonthItems({ key: monthKey, error: errorMessage(e, "明細") });
      });

    return () => {
      cancelled = true;
    };
  }, [monthKey, tagId, year, openMonth, router]);

  const currentReport = report?.key === reportKey ? report : null;
  const data = currentReport?.data;
  const maxAmount = Math.max(1, ...(data?.months.map((m) => m.amount) ?? [0]));
  const currentItems = monthItems?.key === monthKey ? monthItems : null;

  const changeYear = (delta: number) => {
    setYear((y) => y + delta);
    setOpenMonth(null);
  };

  const buttonClass = "rounded-md border border-black/15 px-3 py-1.5 text-sm dark:border-white/15";

  if (tagError) return <p className={errorClass}>{tagError}</p>;

  if (tags !== null && tags.length === 0) {
    return (
      <p className="rounded-xl border border-dashed border-black/15 px-4 py-8 text-center text-sm text-black/50 dark:border-white/15 dark:text-white/50">
        タグがまだありません。「お買い物登録」で明細にタグを付けると、ここで集計できます。
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <select
        aria-label="タグ"
        value={tagId ?? ""}
        onChange={(e) => {
          setTagId(Number(e.target.value));
          setOpenMonth(null);
        }}
        className="rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20"
      >
        {(tags ?? []).map((tag) => (
          <option key={tag.id} value={tag.id}>
            #{tag.name}
          </option>
        ))}
      </select>

      <div className="flex items-center justify-between">
        <button type="button" className={buttonClass} onClick={() => changeYear(-1)}>
          前年
        </button>
        <span className="text-base font-medium">{year} 年</span>
        <button type="button" className={buttonClass} onClick={() => changeYear(1)}>
          翌年
        </button>
      </div>

      {currentReport?.error && <p className={errorClass}>{currentReport.error}</p>}
      {!currentReport && <p className={mutedClass}>読み込み中...</p>}

      {data && (
        <>
          <div className="flex flex-col gap-1 rounded-xl border border-black/10 bg-white px-4 py-4 shadow-sm dark:border-white/10 dark:bg-black/20">
            <span className="text-xs text-black/50 dark:text-white/50">#{data.tag.name} の {data.year} 年の合計</span>
            <span className="text-2xl font-semibold tabular-nums">{formatYen(data.total)}</span>
          </div>

          <ul className="flex flex-col divide-y divide-black/10 rounded-xl border border-black/10 bg-white shadow-sm dark:divide-white/10 dark:border-white/10 dark:bg-black/20">
            {data.months.map(({ month, amount }) => {
              const open = openMonth === month;

              return (
                <li key={month} className="px-4 py-2.5">
                  <button
                    type="button"
                    onClick={() => setOpenMonth(open ? null : month)}
                    aria-expanded={open}
                    disabled={amount === 0}
                    className="flex w-full items-center gap-3 text-left disabled:cursor-default"
                  >
                    <span className="w-10 shrink-0 text-sm tabular-nums text-black/60 dark:text-white/60">{month} 月</span>
                    <span className="h-2 min-w-0 flex-1 rounded bg-black/5 dark:bg-white/10">
                      <span
                        className="block h-2 rounded bg-violet-500"
                        style={{ width: `${(amount / maxAmount) * 100}%` }}
                      />
                    </span>
                    <span className={`w-24 shrink-0 text-right text-sm tabular-nums ${amount === 0 ? "text-black/40 dark:text-white/40" : ""}`}>
                      {formatYen(amount)}
                    </span>
                  </button>

                  {open && (
                    <div className="mt-2">
                      {currentItems?.error && <p className={errorClass}>{currentItems.error}</p>}
                      {!currentItems && <p className={mutedClass}>読み込み中...</p>}
                      {currentItems?.data && (
                        <ul className="flex flex-col gap-1 rounded-md bg-black/5 px-3 py-2 text-xs dark:bg-white/5">
                          {currentItems.data.items.map((item, index) => (
                            <li key={`${item.journal_id}-${index}`} className="flex items-baseline justify-between gap-2">
                              <span className="min-w-0 truncate">
                                {item.journal_date.slice(5).replace("-", "/")} {item.store_name ?? ""}・{item.item_name ?? ""}
                                <span className="text-black/50 dark:text-white/50">（{item.account_name ?? "不明な科目"}）</span>
                              </span>
                              <span className="tabular-nums">{formatYen(item.amount)}</span>
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>
                  )}
                </li>
              );
            })}
          </ul>

          <p className="text-xs text-black/50 dark:text-white/50">
            金額のある月をタップすると、その月の明細を開きます。1 つの明細に複数のタグを付けた場合は、それぞれのタグで数えます。
          </p>
        </>
      )}
    </div>
  );
}
