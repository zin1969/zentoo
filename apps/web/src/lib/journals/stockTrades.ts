import { apiFetch } from "@/lib/api/apiFetch";

export type StockTradeInput = {
  trade_type: "buy" | "sell";
  journal_date: string;
  // 銘柄（種別「投資」の口座）
  stock_account_id: number;
  // 証券口座（預り金）
  securities_account_id: number;
  shares: number;
  // 買い: 証券口座から出ていった額（手数料込み）。売り: 証券口座に入った額（手数料・税金を引いたあと）
  amount: number;
};

// 修正はできない（削除して登録し直す）
export async function createStockTrade(input: StockTradeInput) {
  return apiFetch<{ journal_id: number }>("/stock-trades", { method: "POST", body: input });
}
