import { apiFetch } from "@/lib/api/apiFetch";
import { localToday } from "@/lib/dates/localToday";

export { localToday };

// 決まった収支（家賃・サブスク・給料など）。回ごとに確かめてから仕訳にする

// 1: 支出（借方が費用、貸方が支払い方法の口座かカード）、2: 収入（借方が入金先の口座、貸方が収益科目）、
// 3: 振替（借方が入金先の口座、貸方が出金元の口座かカード）
export const KIND_EXPENSE = 1;
export const KIND_INCOME = 2;
export const KIND_TRANSFER = 3;

export const KIND_LABELS: Record<number, string> = {
  [KIND_EXPENSE]: "支出",
  [KIND_INCOME]: "収入",
  [KIND_TRANSFER]: "振替"
};

// 貸方の科目の種別（1: 資産、2: 負債、4: 収益）
export const ELEMENT_ASSETS = 1;
export const ELEMENT_LIABILITIES = 2;
export const ELEMENT_REVENUE = 4;

// 月単位（開始日の月から interval_count ヶ月ごとの day_of_month 日）。31 は月末
export const INTERVAL_UNIT_MONTH = 1;
// 週単位（interval_count 週ごとの weekday 曜日。0 = 日曜）
export const INTERVAL_UNIT_WEEK = 2;
export const MONTH_END_DAY = 31;
export const WEEKDAY_NAMES = ["日", "月", "火", "水", "木", "金", "土"];

export type RecurringEntryInput = {
  name: string;
  kind: number;
  store_name: string;
  item_name: string;
  amount: number;
  debit_account_id: number;
  credit_element_type: number;
  credit_account_id: number;
  interval_unit: number;
  interval_count: number;
  // 月単位のときだけ
  day_of_month: number | null;
  // 週単位のときだけ
  weekday: number | null;
  start_date: string;
  end_date: string | null;
};

export type RecurringEntry = Omit<RecurringEntryInput, "store_name" | "item_name"> & {
  id: number;
  store_name: string | null;
  item_name: string | null;
  debit_account_name: string | null;
  credit_account_name: string | null;
  // 今日以降の次の予定日。終了していれば null
  next_date: string | null;
};

// まだ登録も飛ばしもしていない回
export type PendingOccurrence = {
  recurring_entry_id: number;
  scheduled_date: string;
  name: string;
  kind: number;
  // 目安の金額
  amount: number;
  store_name: string | null;
  item_name: string | null;
  debit_account_name: string | null;
  credit_account_name: string | null;
  interval_unit: number;
  interval_count: number;
};

export async function getRecurringEntries() {
  return apiFetch<RecurringEntry[]>("/recurring-entries");
}

export async function createRecurringEntry(input: RecurringEntryInput) {
  return apiFetch<{ id: number }>("/recurring-entries", { method: "POST", body: input });
}

export async function updateRecurringEntry(id: number, input: RecurringEntryInput) {
  return apiFetch<{ id: number }>(`/recurring-entries/${id}`, { method: "PUT", body: input });
}

// 回の記録も消える。登録した仕訳は残る
export async function deleteRecurringEntry(id: number) {
  await apiFetch<null>(`/recurring-entries/${id}`, { method: "DELETE" });
}

export async function getPendingOccurrences() {
  return apiFetch<PendingOccurrence[]>("/recurring-entries/pending");
}

// date は仕訳の日付（省略すると予定日）
export async function registerOccurrence(id: number, input: { scheduled_date: string; amount: number; date?: string }) {
  return apiFetch<{ journal_id: number }>(`/recurring-entries/${id}/occurrences`, { method: "POST", body: input });
}

export async function skipOccurrence(id: number, scheduledDate: string) {
  await apiFetch<unknown>(`/recurring-entries/${id}/skips`, { method: "POST", body: { scheduled_date: scheduledDate } });
}

// くり返しの説明（「毎月 27 日」「3 ヶ月ごと 10 日」「毎年 11 月 15 日」「2 週ごと 金曜日」）。毎年は開始日の月
export function scheduleLabel(entry: {
  interval_unit: number;
  interval_count: number;
  day_of_month: number | null;
  weekday: number | null;
  start_date?: string;
}) {
  if (entry.interval_unit === INTERVAL_UNIT_WEEK) {
    const weekday = `${WEEKDAY_NAMES[entry.weekday ?? 0]}曜日`;
    return entry.interval_count === 1 ? `毎週 ${weekday}` : `${entry.interval_count} 週ごと ${weekday}`;
  }

  const day = entry.day_of_month === MONTH_END_DAY ? "月末" : `${entry.day_of_month} 日`;

  if (entry.interval_count === 1) return `毎月 ${day}`;
  if (entry.interval_count === 12 && entry.start_date) {
    return `毎年 ${Number(entry.start_date.slice(5, 7))} 月 ${day}`;
  }

  return `${entry.interval_count} ヶ月ごと ${day}`;
}

function formatDate(year: number, monthIndex: number, day: number) {
  return `${year}-${String(monthIndex + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

type Schedule = {
  intervalUnit: number;
  intervalCount: number;
  dayOfMonth: number;
  weekday: number;
  startDate: string;
  endDate?: string | null;
};

// 予定日を count 個（設定画面で確かめるため）。API の get_recurring_dates と同じ数え方:
// 月単位は開始日の月から intervalCount ヶ月ごと（月に無い日は月末）、週単位は開始日から最初の weekday 曜日から
// intervalCount 週ごと。開始日より前と終了日より後は出さない
export function upcomingDates(schedule: Schedule, from: string, count = 4) {
  return schedule.intervalUnit === INTERVAL_UNIT_WEEK
    ? upcomingWeeklyDates(schedule, from, count)
    : upcomingMonthlyDates(schedule, from, count);
}

function upcomingWeeklyDates({ intervalCount, weekday, startDate, endDate }: Schedule, from: string, count: number) {
  const dates: string[] = [];
  const [year, month, day] = startDate.split("-").map(Number);
  const date = new Date(year, month - 1, day);
  date.setDate(date.getDate() + ((weekday - date.getDay() + 7) % 7));

  for (let step = 0; dates.length < count && step < 2000; step++) {
    const value = formatDate(date.getFullYear(), date.getMonth(), date.getDate());
    if (endDate && value > endDate) break;
    if (value >= from) dates.push(value);

    date.setDate(date.getDate() + intervalCount * 7);
  }

  return dates;
}

function upcomingMonthlyDates({ intervalCount, dayOfMonth, startDate, endDate }: Schedule, from: string, count: number) {
  const dates: string[] = [];
  const startYear = Number(startDate.slice(0, 4));
  const startMonth = Number(startDate.slice(5, 7)) - 1;
  const lowerBound = from > startDate ? from : startDate;

  for (let step = 0; dates.length < count && step < 600; step++) {
    const monthIndex = startMonth + step * intervalCount;
    const year = startYear + Math.floor(monthIndex / 12);
    const month = monthIndex % 12;
    const lastDay = new Date(year, month + 1, 0).getDate();
    const date = formatDate(year, month, Math.min(dayOfMonth, lastDay));

    if (endDate && date > endDate) break;
    if (date >= lowerBound) dates.push(date);
  }

  return dates;
}
