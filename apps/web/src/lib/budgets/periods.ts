import { PERIOD_MONTH, PERIOD_WEEK } from "./budgets";

// "YYYY-MM-DD" を端末のローカル日付として扱う（タイムゾーンでずれないよう、Date の文字列解釈は使わない）
export function parseDate(value: string) {
  const [year, month, day] = value.split("-").map(Number);
  return new Date(year, month - 1, day);
}

export function formatDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");

  return `${date.getFullYear()}-${month}-${day}`;
}

// 前・次の期間の日付。月と年は 1 日にそろえる（31 日から 1 か月ずらして月を飛ばさないように）
export function shiftPeriod(value: string, periodType: number, step: number) {
  const date = parseDate(value);

  if (periodType === PERIOD_WEEK) return formatDate(new Date(date.getFullYear(), date.getMonth(), date.getDate() + 7 * step));
  if (periodType === PERIOD_MONTH) return formatDate(new Date(date.getFullYear(), date.getMonth() + step, 1));

  return formatDate(new Date(date.getFullYear() + step, 0, 1));
}

const WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];

function shortDate(value: string) {
  const date = parseDate(value);
  return `${date.getMonth() + 1}/${date.getDate()}（${WEEKDAYS[date.getDay()]}）`;
}

// 期間の見出し: 週は「11/23（月）〜11/29（日）」、月は「2026年11月」、年は「2026年」
export function periodLabel(periodType: number, start: string, end: string) {
  const date = parseDate(start);

  if (periodType === PERIOD_WEEK) return `${shortDate(start)}〜${shortDate(end)}`;
  if (periodType === PERIOD_MONTH) return `${date.getFullYear()}年${date.getMonth() + 1}月`;

  return `${date.getFullYear()}年`;
}

const DAY_MS = 24 * 60 * 60 * 1000;

// 今日までに過ぎた期間の割合（今日を含む）。期間より前は 0、期間が終わっていれば 1
export function elapsedRatio(start: string, end: string, today: string) {
  const startTime = parseDate(start).getTime();
  const endTime = parseDate(end).getTime();
  const todayTime = parseDate(today).getTime();

  if (todayTime < startTime) return 0;
  if (todayTime >= endTime) return 1;

  const totalDays = Math.round((endTime - startTime) / DAY_MS) + 1;
  const elapsedDays = Math.round((todayTime - startTime) / DAY_MS) + 1;

  return elapsedDays / totalDays;
}
