"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getAssetAccounts, type AssetAccount } from "@/lib/masters/assetAccounts";
import { createStockTrade } from "@/lib/journals/stockTrades";
import {
  estimateSoldCost,
  formatPrice,
  formatShares,
  getStockHoldings,
  type StockHolding
} from "@/lib/reports/stockHoldings";
import { localToday } from "@/lib/dates/localToday";

type Status = "idle" | "submitting" | "success" | "error";
type TradeType = "buy" | "sell";

const SECURITIES = 4;
const INVESTMENT = 5;

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "stock_account_not_found":
        return "銘柄が見つかりません。画面を再読み込みしてください。";
      case "securities_account_not_found":
        return "証券口座が見つかりません。画面を再読み込みしてください。";
      case "insufficient_shares":
        return "売る日に持っている株数より多くは売れません。";
      case "later_sale_exists":
        return "この銘柄には、もっと後の日付の売りがあります。先にその売りを仕訳一覧で削除してから、日付の順に登録し直してください。";
      case "stock_gain_account_not_found":
        return "収益科目「株式売却益」が見つかりません。「口座・カード・科目・タグの管理」で、この名前の収益科目を作ってください。";
      case "stock_loss_account_not_found":
        return "費用科目「株式売却損」が見つかりません。「口座・カード・科目・タグの管理」で、この名前の費用科目を作ってください。";
    }

    if (error.data?.errors?.length) {
      return error.data.errors.join(" / ");
    }
  }

  return "登録に失敗しました。時間をおいて再度お試しください。";
}

// 株の売買（買い: 証券口座 → 銘柄、売り: 銘柄 → 証券口座。差額は売却益・売却損）の登録
export default function StockTradeForm() {
  const router = useRouter();

  const [tradeType, setTradeType] = useState<TradeType>("buy");
  const [date, setDate] = useState(localToday);
  const [stockId, setStockId] = useState("");
  const [securitiesId, setSecuritiesId] = useState("");
  const [shares, setShares] = useState("");
  const [amount, setAmount] = useState("");

  const [assetAccounts, setAssetAccounts] = useState<AssetAccount[]>([]);
  const [holdings, setHoldings] = useState<StockHolding[]>([]);
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string | null>(null);

  const handleLoadError = useCallback(
    (e: unknown) => {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }

      setError("口座・保有株の取得に失敗しました。時間をおいて再度お試しください。");
    },
    [router]
  );

  useEffect(() => {
    let cancelled = false;

    Promise.all([getAssetAccounts(), getStockHoldings()])
      .then(([assets, stockHoldings]) => {
        if (cancelled) return;

        setAssetAccounts(assets);
        setHoldings(stockHoldings.holdings);

        // 証券口座が 1 つだけなら、最初から選んでおく
        const securitiesAccounts = assets.filter((a) => a.payment_method_type === SECURITIES);
        if (securitiesAccounts.length === 1) setSecuritiesId(String(securitiesAccounts[0].id));
      })
      .catch((e) => {
        if (!cancelled) handleLoadError(e);
      });

    return () => {
      cancelled = true;
    };
  }, [handleLoadError]);

  const stocks = assetAccounts.filter((a) => a.payment_method_type === INVESTMENT);
  const securitiesAccounts = assetAccounts.filter((a) => a.payment_method_type === SECURITIES);
  const holding = holdings.find((h) => String(h.account_id) === stockId);

  // 売りの損益の目安（今日時点の保有株から）。実際の取得額は、売った日までの売買から Rails が計算する
  const sharesNumber = Number(shares);
  const amountNumber = Number(amount);
  const soldCost =
    tradeType === "sell" && holding && holding.shares > 0 && sharesNumber > 0 && sharesNumber <= holding.shares
      ? estimateSoldCost(holding, sharesNumber)
      : null;
  const gainOrLoss = soldCost !== null && amountNumber > 0 ? amountNumber - soldCost : null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("submitting");
    setError(null);

    try {
      await createStockTrade({
        trade_type: tradeType,
        journal_date: date,
        stock_account_id: Number(stockId),
        securities_account_id: Number(securitiesId),
        shares: sharesNumber,
        amount: amountNumber
      });

      setStatus("success");
      setShares("");
      setAmount("");

      // 登録した分を反映した保有株を出し直す
      getStockHoldings()
        .then((stockHoldings) => setHoldings(stockHoldings.holdings))
        .catch(handleLoadError);
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        router.replace("/login");
        return;
      }

      setStatus("error");
      setError(errorMessage(err));
    }
  };

  const isSubmitting = status === "submitting";
  const inputClass =
    "rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";
  const labelClass = "text-sm font-medium text-foreground";
  const hintClass = "text-xs text-black/50 dark:text-white/50";
  const tabClass = (active: boolean) =>
    `flex-1 rounded-md px-3 py-1.5 text-sm font-medium transition-colors ${
      active ? "bg-blue-600 text-white" : "text-black/60 hover:text-black dark:text-white/60 dark:hover:text-white"
    }`;

  return (
    <form
      onSubmit={handleSubmit}
      className="flex w-full flex-col gap-5 rounded-xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-black/20"
    >
      {status === "success" && (
        <p className="rounded-md bg-green-50 px-3 py-2 text-sm text-green-700 dark:bg-green-900/30 dark:text-green-300">
          登録しました。
        </p>
      )}

      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {error}
        </p>
      )}

      <div className="flex gap-1 rounded-lg border border-black/10 p-1 dark:border-white/10" role="group" aria-label="売買">
        <button type="button" className={tabClass(tradeType === "buy")} onClick={() => setTradeType("buy")}>
          買い
        </button>
        <button type="button" className={tabClass(tradeType === "sell")} onClick={() => setTradeType("sell")}>
          売り
        </button>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="stock-trade-date" className={labelClass}>
          約定日
        </label>
        <input
          id="stock-trade-date"
          type="date"
          value={date}
          onChange={(e) => setDate(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="stock-trade-stock" className={labelClass}>
          銘柄
        </label>
        <select
          id="stock-trade-stock"
          value={stockId}
          onChange={(e) => setStockId(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">銘柄を選択</option>
          {stocks.map((account) => (
            <option key={account.id} value={account.id}>
              {account.name}
            </option>
          ))}
        </select>
        {holding && holding.shares > 0 && (
          <span className={hintClass}>
            いま {formatShares(holding.shares)}・取得額 {formatYen(holding.cost)}
            {holding.average_price !== null && `（平均 ${formatPrice(holding.average_price)}）`}
          </span>
        )}
        {assetAccounts.length > 0 && stocks.length === 0 && (
          <span className={hintClass}>
            銘柄がありません。「口座・カード・科目・タグの管理」で、種別「投資」の口座を銘柄ごとに作ってください（例: トヨタ 7203）。
          </span>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="stock-trade-securities" className={labelClass}>
          証券口座（預り金）
        </label>
        <select
          id="stock-trade-securities"
          value={securitiesId}
          onChange={(e) => setSecuritiesId(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">証券口座を選択</option>
          {securitiesAccounts.map((account) => (
            <option key={account.id} value={account.id}>
              {account.name}
            </option>
          ))}
        </select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="stock-trade-shares" className={labelClass}>
          株数
        </label>
        <div className="relative">
          <input
            id="stock-trade-shares"
            type="number"
            min="1"
            step="1"
            inputMode="numeric"
            value={shares}
            onChange={(e) => setShares(e.target.value)}
            required
            className={`${inputClass} w-full pr-8 text-right`}
          />
          <span className="pointer-events-none absolute inset-y-0 right-3 flex items-center text-sm text-black/40 dark:text-white/40">
            株
          </span>
        </div>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="stock-trade-amount" className={labelClass}>
          受渡金額
        </label>
        <div className="relative">
          <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-black/40 dark:text-white/40">
            ¥
          </span>
          <input
            id="stock-trade-amount"
            type="number"
            min="1"
            step="1"
            inputMode="numeric"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
            className={`${inputClass} w-full pl-7 text-right`}
          />
        </div>
        <span className={hintClass}>
          {tradeType === "buy"
            ? "証券口座から出ていった額（手数料込み）。手数料も取得額に含めます。"
            : "証券口座に入った額（手数料・税金を引いたあと）。"}
        </span>
        {tradeType === "buy" && sharesNumber > 0 && amountNumber > 0 && (
          <span className={hintClass}>1 株あたり {formatPrice(Math.round((amountNumber / sharesNumber) * 100) / 100)}</span>
        )}
      </div>

      {soldCost !== null && (
        <div className="flex flex-col gap-1 rounded-md bg-black/5 px-3 py-2 text-sm dark:bg-white/5">
          <div className="flex justify-between">
            <span>減る取得額（移動平均）</span>
            <span className="tabular-nums">{formatYen(soldCost)}</span>
          </div>
          {gainOrLoss !== null && (
            <div className="flex justify-between font-medium">
              <span>{gainOrLoss >= 0 ? "売却益" : "売却損"}</span>
              <span className="tabular-nums">{formatYen(Math.abs(gainOrLoss))}</span>
            </div>
          )}
          <span className={hintClass}>今日時点の保有株からの目安です。登録では、約定日までの売買から計算します。</span>
        </div>
      )}

      <button
        type="submit"
        disabled={isSubmitting}
        className="mt-2 inline-flex items-center justify-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
      >
        {isSubmitting ? "登録中..." : tradeType === "buy" ? "買いを登録" : "売りを登録"}
      </button>

      <p className={hintClass}>
        売買は修正できません。間違えたときは仕訳一覧で削除して登録し直してください。配当は
        <Link href="/income-journals" className="underline">
          収入登録
        </Link>
        で、入金先を証券口座、科目を「配当金」にして、手取りの額で登録します。
      </p>
    </form>
  );
}
