import { apiFetch } from "@/lib/api/apiFetch";

export type StockHolding = {
  account_id: number;
  account_name: string;
  shares: number;
  // 取得額（銘柄の口座の残高）
  cost: number;
  // 平均取得単価（取得額 ÷ 株数、小数第 2 位まで）。全部売って株数が 0 のときは null
  average_price: number | null;
};

export type StockHoldings = {
  date: string;
  holdings: StockHolding[];
  total_cost: number;
};

// date を省略すると、Rails が今日（日本時間）で計算する
export async function getStockHoldings(date?: string) {
  const query = date ? `?${new URLSearchParams({ date })}` : "";

  return apiFetch<StockHoldings>(`/stock-holdings${query}`);
}

// 売りで減る取得額の目安（移動平均）。Rails と同じく四捨五入し、全部売るときは取得額をそのまま減らす
export function estimateSoldCost(holding: StockHolding, shares: number) {
  if (shares >= holding.shares) return holding.cost;

  return Math.round((holding.cost * shares) / holding.shares);
}

export function formatShares(shares: number) {
  return `${shares.toLocaleString("ja-JP")} 株`;
}

export function formatPrice(price: number) {
  return `¥${price.toLocaleString("ja-JP", { maximumFractionDigits: 2 })}`;
}
