import { apiFetch } from "@/lib/api/apiFetch";

export type TagReport = {
  tag: { id: number; name: string };
  year: number;
  // 年の合計
  total: number;
  // 1〜12 月の合計（明細の無い月は 0）
  months: { month: number; amount: number }[];
};

export type TagReportItem = {
  journal_id: number;
  journal_date: string;
  store_name: string | null;
  item_name: string | null;
  account_id: number;
  account_name: string | null;
  amount: number;
};

export type TagReportItems = {
  tag: { id: number; name: string };
  month: string;
  total: number;
  items: TagReportItem[];
};

export async function getTagReport(tagId: number, year: number) {
  return apiFetch<TagReport>(`/tag-reports/${tagId}?${new URLSearchParams({ year: String(year) })}`);
}

// month は YYYY-MM
export async function getTagReportItems(tagId: number, month: string) {
  return apiFetch<TagReportItems>(`/tag-reports/${tagId}/items?${new URLSearchParams({ month })}`);
}
