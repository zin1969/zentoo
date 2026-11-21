"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getAssetAccounts, type AssetAccount } from "@/lib/masters/assetAccounts";
import { getBankAccountLedger, type BankAccountLedger, type LedgerEntry } from "@/lib/reports/bankAccountLedger";

const DEPOSIT_ASSET_TYPE = 2;

type Period = { from?: string; to?: string };

type Loaded = {
  key: string;
  data?: BankAccountLedger;
  error?: string;
};

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

// 年が同じ通帳の中で読みやすいよう「MM/DD」で表示する
function formatDate(date: string) {
  return date.slice(5).replace("-", "/");
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    if (error.status === 422) {
      return error.data?.errors?.join(" / ") ?? "期間の指定が正しくありません。";
    }

    if (error.status === 404) {
      return "口座が見つかりません。画面を再読み込みしてください。";
    }
  }

  return "通帳の取得に失敗しました。時間をおいて再度お試しください。";
}

function entryKey(entry: LedgerEntry, index: number) {
  return `${entry.row_type}-${entry.date}-${entry.card_account_id ?? ""}-${entry.journal_ids[0] ?? index}`;
}

type EntryRowProps = {
  entry: LedgerEntry;
  open: boolean;
  onToggle: () => void;
};

function EntryRow({ entry, open, onToggle }: EntryRowProps) {
  const isCard = entry.row_type === "card_payment";
  const isShort = entry.balance < 0;

  const content = (
    <div className="flex flex-col gap-0.5">
      <div className="flex items-baseline gap-2">
        <span className="w-12 shrink-0 text-sm tabular-nums text-black/60 dark:text-white/60">
          {entry.row_type === "carried_over" ? "" : formatDate(entry.date)}
        </span>
        <span className="min-w-0 flex-1 truncate text-sm text-foreground">
          {entry.description ?? "(摘要なし)"}
          {isCard && ` (${entry.items.length} 件)`}
        </span>
        {entry.scheduled && (
          <span className="shrink-0 rounded bg-amber-100 px-1.5 py-0.5 text-xs text-amber-800 dark:bg-amber-900/30 dark:text-amber-300">
            予定
          </span>
        )}
      </div>
      <div className="flex items-baseline justify-between gap-2 pl-14 text-sm tabular-nums">
        <span>
          {entry.withdrawal > 0 && <span className="text-red-700 dark:text-red-300">出金 {formatYen(entry.withdrawal)}</span>}
          {entry.deposit > 0 && <span className="text-blue-700 dark:text-blue-300">入金 {formatYen(entry.deposit)}</span>}
        </span>
        <span className={isShort ? "font-semibold text-red-700 dark:text-red-300" : "text-foreground"}>
          {isShort && "不足 "}
          {formatYen(entry.balance)}
        </span>
      </div>
    </div>
  );

  return (
    <li className={entry.scheduled ? "bg-amber-50/50 py-2.5 dark:bg-amber-900/10" : "py-2.5"}>
      {isCard ? (
        <button type="button" onClick={onToggle} aria-expanded={open} className="w-full text-left">
          {content}
        </button>
      ) : (
        content
      )}

      {/* カードの行は、同じ日・同じカードの引き落としのまとめ。開くと元のお買い物の内訳を出す */}
      {isCard && open && (
        <ul className="mt-2 flex flex-col gap-1 rounded-md bg-black/5 px-3 py-2 pl-14 text-xs dark:bg-white/5">
          {entry.items.map((item) => (
            <li key={item.journal_id} className="flex items-baseline justify-between gap-2">
              <span className="min-w-0 truncate">
                {formatDate(item.journal_date)} {item.store_name ?? ""}
              </span>
              <span className="tabular-nums">{formatYen(item.amount)}</span>
            </li>
          ))}
        </ul>
      )}
    </li>
  );
}

// 預金口座の通帳。繰越から残高を積み上げ、未来の引き落とし予定と残高の不足も出す
export default function BankAccountLedgerView() {
  const router = useRouter();
  const [accounts, setAccounts] = useState<AssetAccount[] | null>(null);
  const [accountId, setAccountId] = useState<number | null>(null);
  // 空の日付は、Rails の既定の期間（先月の初め〜最後の予定日）を使う
  const [period, setPeriod] = useState<Period>({});
  const [loaded, setLoaded] = useState<Loaded | null>(null);
  const [openKeys, setOpenKeys] = useState<Set<string>>(new Set());
  const [accountError, setAccountError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    getAssetAccounts()
      .then((data) => {
        if (cancelled) return;

        const deposits = data.filter((account) => account.payment_method_type === DEPOSIT_ASSET_TYPE);
        setAccounts(deposits);
        setAccountId((current) => current ?? deposits[0]?.id ?? null);
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setAccountError("口座の取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [router]);

  const key = `${accountId}|${period.from ?? ""}|${period.to ?? ""}`;

  useEffect(() => {
    if (accountId === null) return;

    let cancelled = false;

    getBankAccountLedger(accountId, period)
      .then((data) => {
        if (!cancelled) setLoaded({ key, data });
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setLoaded({ key, error: errorMessage(e) });
      });

    return () => {
      cancelled = true;
    };
  }, [key, accountId, period, router]);

  const current = loaded?.key === key ? loaded : null;
  const data = current?.data;
  const shortEntry = data?.entries.find((entry) => entry.balance < 0);

  const toggle = (entryId: string) => {
    setOpenKeys((keys) => {
      const next = new Set(keys);
      if (next.has(entryId)) {
        next.delete(entryId);
      } else {
        next.add(entryId);
      }
      return next;
    });
  };

  const inputClass =
    "min-w-0 flex-1 rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";

  if (accountError) {
    return (
      <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
        {accountError}
      </p>
    );
  }

  if (accounts !== null && accounts.length === 0) {
    return (
      <p className="rounded-xl border border-dashed border-black/15 px-4 py-8 text-center text-sm text-black/50 dark:border-white/15 dark:text-white/50">
        預金口座がありません。「口座・カード・科目の管理」から追加してください。
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <select
        aria-label="口座"
        value={accountId ?? ""}
        onChange={(e) => {
          setAccountId(Number(e.target.value));
          setOpenKeys(new Set());
        }}
        className={inputClass}
      >
        {(accounts ?? []).map((account) => (
          <option key={account.id} value={account.id}>
            {account.name}
          </option>
        ))}
      </select>

      <div className="flex items-center gap-2">
        <input
          type="date"
          aria-label="開始日"
          value={period.from ?? data?.from ?? ""}
          onChange={(e) => setPeriod((p) => ({ ...p, from: e.target.value || undefined }))}
          className={inputClass}
        />
        <span className="text-sm text-black/50 dark:text-white/50">〜</span>
        <input
          type="date"
          aria-label="終了日"
          value={period.to ?? data?.to ?? ""}
          onChange={(e) => setPeriod((p) => ({ ...p, to: e.target.value || undefined }))}
          className={inputClass}
        />
      </div>

      {current?.error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {current.error}
        </p>
      )}

      {!current && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>}

      {data && (
        <>
          {shortEntry && (
            <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
              {formatDate(shortEntry.date)} に残高が {formatYen(-shortEntry.balance)} 足りなくなります。
            </p>
          )}

          <ul className="flex flex-col divide-y divide-black/10 rounded-xl border border-black/10 bg-white px-4 shadow-sm dark:divide-white/10 dark:border-white/10 dark:bg-black/20">
            {data.entries.map((entry, index) => {
              const id = entryKey(entry, index);

              return <EntryRow key={id} entry={entry} open={openKeys.has(id)} onToggle={() => toggle(id)} />;
            })}
          </ul>

          <p className="text-xs text-black/50 dark:text-white/50">
            今日（{formatDate(data.today)}）より後の行は予定です。カードの引き落としは、同じ日・同じカードの分を 1 行にまとめています（タップで内訳）。
          </p>
        </>
      )}
    </div>
  );
}
