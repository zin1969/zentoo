"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import {
  KIND_EXPENSE,
  KIND_LABELS,
  KIND_TRANSFER,
  getPendingOccurrences,
  localToday,
  registerOccurrence,
  skipOccurrence,
  type PendingOccurrence
} from "@/lib/recurring/recurringEntries";
import { buttonClass, errorClass, inputClass, noteClass, primaryButtonClass, sectionClass } from "../../accounts/components/styles";

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "occurrence_already_recorded":
        return "この回はすでに登録されているか、飛ばしてあります。画面を再読み込みしてください。";
      case "not_scheduled_date":
      case "recurring_entry_not_found":
        return "決まった収支の設定が変わっています。画面を再読み込みしてください。";
      case "account_not_found":
        return "科目・口座が見つかりません。決まった収支の設定を確かめてください。";
      case "credit_card_setting_not_found":
        return "クレジットカードの引き落とし設定が見つかりません。";
      case "same_account":
        return "出金元と入金先が同じ口座です。決まった収支の設定を確かめてください。";
      case "credit_card_charge_requires_e_money":
        return "クレジットカードから入れられるのは、電子マネーだけです。決まった収支の設定を確かめてください。";
    }

    if (error.data?.errors?.length) {
      return error.data.errors.join(" / ");
    }
  }

  return "登録に失敗しました。時間をおいて再度お試しください。";
}

function occurrenceKey(occurrence: PendingOccurrence) {
  return `${occurrence.recurring_entry_id}-${occurrence.scheduled_date}`;
}

function formatDate(date: string) {
  const [year, month, day] = date.split("-").map(Number);
  const weekday = "日月火水木金土"[new Date(year, month - 1, day).getDay()];

  return `${month}/${day}（${weekday}）`;
}

type RowProps = {
  occurrence: PendingOccurrence;
  overdue: boolean;
  busy: boolean;
  onRegister: (amount: number, date: string) => void;
  onSkip: () => void;
};

// 1 回分。金額と支払った日を確かめて（直して）登録するか、飛ばす
function OccurrenceRow({ occurrence, overdue, busy, onRegister, onSkip }: RowProps) {
  const [amount, setAmount] = useState(String(occurrence.amount));
  const [date, setDate] = useState(occurrence.scheduled_date);
  const isExpense = occurrence.kind === KIND_EXPENSE;
  const dateLabel = isExpense ? "支払った日" : occurrence.kind === KIND_TRANSFER ? "振り替えた日" : "入金された日";
  const amountValid = /^\d+$/.test(amount) && Number(amount) > 0;

  return (
    <li className="flex flex-col gap-2 py-3">
      <div className="flex items-baseline justify-between gap-2">
        <span className="truncate text-sm font-medium text-foreground">
          {occurrence.name}
          <span className="ml-1.5 text-xs font-normal text-black/50 dark:text-white/50">{KIND_LABELS[occurrence.kind]}</span>
        </span>
        <span
          className={`shrink-0 text-xs tabular-nums ${overdue ? "text-red-600 dark:text-red-400" : "text-black/55 dark:text-white/55"}`}
        >
          {formatDate(occurrence.scheduled_date)}
          {overdue ? " · 未登録" : ""}
        </span>
      </div>
      <span className={noteClass}>
        {occurrence.debit_account_name ?? "?"} ← {occurrence.credit_account_name ?? "?"}
        {occurrence.store_name ? ` · ${occurrence.store_name}` : ""}
      </span>
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative w-28">
          <span className="pointer-events-none absolute inset-y-0 left-2.5 flex items-center text-sm text-black/40 dark:text-white/40">
            ¥
          </span>
          <input
            type="number"
            min="1"
            aria-label={`${occurrence.name}の金額`}
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className={`${inputClass} w-full pl-6 text-right`}
          />
        </div>
        <input
          type="date"
          aria-label={`${occurrence.name}の${dateLabel}`}
          value={date}
          onChange={(e) => setDate(e.target.value)}
          className={`${inputClass} w-36`}
        />
        <div className="ml-auto flex gap-2">
          <button type="button" onClick={onSkip} disabled={busy} className={buttonClass}>
            今回はなし
          </button>
          <button
            type="button"
            onClick={() => onRegister(Number(amount), date)}
            disabled={busy || !amountValid || !date}
            className={primaryButtonClass}
          >
            登録
          </button>
        </div>
      </div>
    </li>
  );
}

// 今月の末日までの、まだ登録していない決まった収支（先月以前の取り残しも含む）
export default function PendingOccurrences() {
  const router = useRouter();
  const [occurrences, setOccurrences] = useState<PendingOccurrence[] | null>(null);
  const [reloadCount, setReloadCount] = useState(0);
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const today = localToday();

  useEffect(() => {
    let cancelled = false;

    getPendingOccurrences()
      .then((data) => {
        if (!cancelled) setOccurrences(data);
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setError("決まった収支の取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [reloadCount, router]);

  // 登録・飛ばすをして、成功したら一覧を読み直す（その回は一覧から消える）
  const run = async (occurrence: PendingOccurrence, action: () => Promise<unknown>, done: string) => {
    setBusyKey(occurrenceKey(occurrence));
    setMessage(null);
    setError(null);

    try {
      await action();
      setMessage(done);
      setReloadCount((n) => n + 1);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }

      setError(errorMessage(e));
    } finally {
      setBusyKey(null);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      {message && (
        <p className="rounded-md bg-green-50 px-3 py-2 text-sm text-green-700 dark:bg-green-900/30 dark:text-green-300">
          {message}
        </p>
      )}
      {error && <p className={errorClass}>{error}</p>}

      <section className={sectionClass}>
        {occurrences === null ? (
          !error && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>
        ) : occurrences.length === 0 ? (
          <p className={noteClass}>今月の決まった収支は、すべて登録済みです。</p>
        ) : (
          <ul className="flex flex-col divide-y divide-black/10 dark:divide-white/10">
            {occurrences.map((occurrence) => (
              <OccurrenceRow
                key={occurrenceKey(occurrence)}
                occurrence={occurrence}
                overdue={occurrence.scheduled_date < today}
                busy={busyKey !== null}
                onRegister={(amount, date) =>
                  run(
                    occurrence,
                    () =>
                      registerOccurrence(occurrence.recurring_entry_id, {
                        scheduled_date: occurrence.scheduled_date,
                        amount,
                        date
                      }),
                    `「${occurrence.name}」（${formatDate(occurrence.scheduled_date)}）を登録しました。`
                  )
                }
                onSkip={() =>
                  run(
                    occurrence,
                    () => skipOccurrence(occurrence.recurring_entry_id, occurrence.scheduled_date),
                    `「${occurrence.name}」（${formatDate(occurrence.scheduled_date)}）は今回はなしにしました。`
                  )
                }
              />
            ))}
          </ul>
        )}
        <p className={noteClass}>
          金額と日付を確かめてから「登録」を押すと、仕訳になります。登録した仕訳を削除すると、その回はまた未登録に戻ります。
        </p>
      </section>

      <Link href="/recurring-entries/settings" className={`${buttonClass} text-center`}>
        決まった収支の設定
      </Link>
    </div>
  );
}
