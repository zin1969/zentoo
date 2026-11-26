"use client";

import { useState } from "react";
import { ASSET_TYPES, PAYMENT_ASSET_TYPES, type AssetAccount } from "@/lib/masters/assetAccounts";
import type { LiabilityAccount } from "@/lib/masters/liabilityAccounts";
import type { TwoLevelAccount } from "@/lib/masters/twoLevelAccounts";
import {
  ELEMENT_ASSETS,
  ELEMENT_LIABILITIES,
  ELEMENT_REVENUE,
  INTERVAL_UNIT_MONTH,
  INTERVAL_UNIT_WEEK,
  KIND_EXPENSE,
  KIND_INCOME,
  MONTH_END_DAY,
  WEEKDAY_NAMES,
  localToday,
  upcomingDates,
  type RecurringEntry,
  type RecurringEntryInput
} from "@/lib/recurring/recurringEntries";
import { buttonClass, inputClass, noteClass, primaryButtonClass } from "../../accounts/components/styles";

const MAX_NAME_LENGTH = 30;
const MAX_TEXT_LENGTH = 100;
const MAX_INTERVAL_COUNT = 12;
const YEARLY_INTERVAL_COUNT = 12;

// くり返し。毎年は「開始日の月から 12 ヶ月ごと」、毎週は「N 週ごとの何曜日」（毎週は 1 週ごと）
type Repeat = "monthly" | "every_n_months" | "yearly" | "weekly";

const REPEATS: { value: Repeat; label: string }[] = [
  { value: "monthly", label: "毎月" },
  { value: "every_n_months", label: "N ヶ月ごと" },
  { value: "yearly", label: "毎年" },
  { value: "weekly", label: "毎週" }
];

const DAYS = Array.from({ length: MONTH_END_DAY - 1 }, (_, i) => i + 1);

export type Accounts = {
  expense: TwoLevelAccount[];
  revenue: TwoLevelAccount[];
  asset: AssetAccount[];
  liability: LiabilityAccount[];
};

function repeatOf(intervalUnit: number, intervalCount: number): Repeat {
  if (intervalUnit === INTERVAL_UNIT_WEEK) return "weekly";
  if (intervalCount === 1) return "monthly";
  if (intervalCount === YEARLY_INTERVAL_COUNT) return "yearly";

  return "every_n_months";
}

function formatDate(date: string) {
  const [year, month, day] = date.split("-").map(Number);
  const weekday = "日月火水木金土"[new Date(year, month - 1, day).getDay()];

  return `${year}/${month}/${day}（${weekday}）`;
}

// 親子 2 階層の科目を 1 つの選択欄にする。子科目のある親は、グループの中で「〇〇のまま」も選べる
function TwoLevelAccountOptions({ accounts }: { accounts: TwoLevelAccount[] }) {
  const ids = new Set(accounts.map((a) => a.id));
  const topLevel = accounts.filter((a) => a.parent_id === null || !ids.has(a.parent_id));

  return topLevel.map((parent) => {
    const children = accounts.filter((a) => a.parent_id === parent.id);
    if (children.length === 0) {
      return (
        <option key={parent.id} value={parent.id}>
          {parent.name}
        </option>
      );
    }

    return (
      <optgroup key={parent.id} label={parent.name}>
        <option value={parent.id}>（{parent.name}のまま）</option>
        {children.map((child) => (
          <option key={child.id} value={child.id}>
            {child.name}
          </option>
        ))}
      </optgroup>
    );
  });
}

type Props = {
  // 渡されたときは変更
  entry?: RecurringEntry;
  accounts: Accounts;
  busy: boolean;
  onSubmit: (input: RecurringEntryInput) => void;
  onCancel: () => void;
};

// 決まった収支の追加・変更。くり返しを切り替えると入力欄が変わり、次の予定日で確かめられる
export default function RecurringEntryForm({ entry, accounts, busy, onSubmit, onCancel }: Props) {
  const [name, setName] = useState(entry?.name ?? "");
  const [kind, setKind] = useState(entry?.kind ?? KIND_EXPENSE);
  // 支出: 費用科目、収入: 入金先の口座
  const [debitAccountId, setDebitAccountId] = useState(entry ? String(entry.debit_account_id) : "");
  // 支出: 「1-口座の ID」か「2-カードの ID」、収入: 収益科目の ID
  const [creditKey, setCreditKey] = useState(
    entry
      ? entry.kind === KIND_EXPENSE
        ? `${entry.credit_element_type}-${entry.credit_account_id}`
        : String(entry.credit_account_id)
      : ""
  );
  const [amount, setAmount] = useState(entry ? String(entry.amount) : "");
  const [storeName, setStoreName] = useState(entry?.store_name ?? "");
  const [itemName, setItemName] = useState(entry?.item_name ?? "");
  const initialRepeat = repeatOf(entry?.interval_unit ?? INTERVAL_UNIT_MONTH, entry?.interval_count ?? 1);
  const [repeat, setRepeat] = useState<Repeat>(initialRepeat);
  const [intervalCount, setIntervalCount] = useState(
    entry && initialRepeat === "every_n_months" ? String(entry.interval_count) : "3"
  );
  const [weekInterval, setWeekInterval] = useState(entry && initialRepeat === "weekly" ? String(entry.interval_count) : "1");
  const [dayOfMonth, setDayOfMonth] = useState(String(entry?.day_of_month ?? 27));
  const [weekday, setWeekday] = useState(String(entry?.weekday ?? 5));
  const [startDate, setStartDate] = useState(entry?.start_date ?? localToday());
  const [endDate, setEndDate] = useState(entry?.end_date ?? "");

  const isExpense = kind === KIND_EXPENSE;
  const isWeekly = repeat === "weekly";
  const intervalUnit = isWeekly ? INTERVAL_UNIT_WEEK : INTERVAL_UNIT_MONTH;
  const count = {
    monthly: 1,
    yearly: YEARLY_INTERVAL_COUNT,
    every_n_months: Number(intervalCount) || 0,
    weekly: Number(weekInterval) || 0
  }[repeat];
  const countValid = Number.isInteger(count) && count >= 1 && count <= MAX_INTERVAL_COUNT;
  const preview =
    countValid && startDate
      ? upcomingDates(
          {
            intervalUnit,
            intervalCount: count,
            dayOfMonth: Number(dayOfMonth),
            weekday: Number(weekday),
            startDate,
            endDate
          },
          localToday()
        )
      : [];

  const changeKind = (next: number) => {
    setKind(next);
    // 支出と収入では、選べる科目が違う
    setDebitAccountId("");
    setCreditKey("");
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    const [creditElementType, creditAccountId] = isExpense
      ? creditKey.split("-").map(Number)
      : [ELEMENT_REVENUE, Number(creditKey)];

    onSubmit({
      name: name.trim(),
      kind,
      store_name: storeName.trim(),
      item_name: itemName.trim(),
      amount: Number(amount),
      debit_account_id: Number(debitAccountId),
      credit_element_type: creditElementType,
      credit_account_id: creditAccountId,
      interval_unit: intervalUnit,
      interval_count: count,
      day_of_month: isWeekly ? null : Number(dayOfMonth),
      weekday: isWeekly ? Number(weekday) : null,
      start_date: startDate,
      end_date: endDate || null
    });
  };

  const labelClass = "text-sm font-medium text-foreground";
  const chipClass = (selected: boolean) =>
    selected
      ? "rounded-md bg-white px-3 py-1.5 text-sm font-medium text-foreground shadow-sm dark:bg-black/40"
      : "rounded-md px-3 py-1.5 text-sm text-black/60 dark:text-white/60";

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <div className="flex flex-col gap-1.5">
        <label htmlFor="recurring-name" className={labelClass}>
          名前
        </label>
        <input
          id="recurring-name"
          type="text"
          placeholder="家賃"
          value={name}
          maxLength={MAX_NAME_LENGTH}
          onChange={(e) => setName(e.target.value)}
          required
          className={inputClass}
        />
      </div>

      <div className="grid grid-cols-2 gap-1 rounded-lg bg-black/5 p-1 dark:bg-white/10" role="radiogroup" aria-label="種類">
        {(
          [
            [KIND_EXPENSE, "支出"],
            [KIND_INCOME, "収入"]
          ] as const
        ).map(([value, label]) => (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={kind === value}
            onClick={() => changeKind(value)}
            className={chipClass(kind === value)}
          >
            {label}
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="recurring-debit" className={labelClass}>
          {isExpense ? "費用科目" : "入金先"}
        </label>
        <select
          id="recurring-debit"
          value={debitAccountId}
          onChange={(e) => setDebitAccountId(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">{isExpense ? "費用科目を選択" : "入金先を選択"}</option>
          {isExpense ? (
            <TwoLevelAccountOptions accounts={accounts.expense} />
          ) : (
            ASSET_TYPES.map((type) => (
              <optgroup key={type.value} label={type.label}>
                {accounts.asset
                  .filter((a) => a.payment_method_type === type.value)
                  .map((a) => (
                    <option key={a.id} value={a.id}>
                      {a.name}
                    </option>
                  ))}
              </optgroup>
            ))
          )}
        </select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="recurring-credit" className={labelClass}>
          {isExpense ? "支払い方法" : "収益科目"}
        </label>
        <select
          id="recurring-credit"
          value={creditKey}
          onChange={(e) => setCreditKey(e.target.value)}
          required
          className={inputClass}
        >
          <option value="">{isExpense ? "支払い方法を選択" : "収益科目を選択"}</option>
          {isExpense ? (
            <>
              {PAYMENT_ASSET_TYPES.map((type) => (
                <optgroup key={type.value} label={type.label}>
                  {accounts.asset
                    .filter((a) => a.payment_method_type === type.value)
                    .map((a) => (
                      <option key={a.id} value={`${ELEMENT_ASSETS}-${a.id}`}>
                        {a.name}
                      </option>
                    ))}
                </optgroup>
              ))}
              <optgroup label="カード・借入">
                {accounts.liability.map((a) => (
                  <option key={a.id} value={`${ELEMENT_LIABILITIES}-${a.id}`}>
                    {a.name}
                  </option>
                ))}
              </optgroup>
            </>
          ) : (
            <TwoLevelAccountOptions accounts={accounts.revenue} />
          )}
        </select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="recurring-amount" className={labelClass}>
          金額（目安。登録のときに直せます）
        </label>
        <div className="relative">
          <span className="pointer-events-none absolute inset-y-0 left-2.5 flex items-center text-sm text-black/40 dark:text-white/40">
            ¥
          </span>
          <input
            id="recurring-amount"
            type="number"
            min="1"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
            className={`${inputClass} w-full pl-6 text-right`}
          />
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <div className="flex flex-col gap-1.5">
          <label htmlFor="recurring-store" className={labelClass}>
            {isExpense ? "店舗名（任意）" : "支払元（任意）"}
          </label>
          <input
            id="recurring-store"
            type="text"
            value={storeName}
            maxLength={MAX_TEXT_LENGTH}
            onChange={(e) => setStoreName(e.target.value)}
            className={inputClass}
          />
        </div>
        {isExpense && (
          <div className="flex flex-col gap-1.5">
            <label htmlFor="recurring-item" className={labelClass}>
              品目（任意）
            </label>
            <input
              id="recurring-item"
              type="text"
              placeholder={name || "空なら名前"}
              value={itemName}
              maxLength={MAX_TEXT_LENGTH}
              onChange={(e) => setItemName(e.target.value)}
              className={inputClass}
            />
          </div>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <span className={labelClass}>くり返し</span>
        <div className="grid grid-cols-4 gap-1 rounded-lg bg-black/5 p-1 dark:bg-white/10" role="radiogroup" aria-label="くり返し">
          {REPEATS.map((item) => (
            <button
              key={item.value}
              type="button"
              role="radio"
              aria-checked={repeat === item.value}
              onClick={() => setRepeat(item.value)}
              className={chipClass(repeat === item.value)}
            >
              {item.label}
            </button>
          ))}
        </div>
        <div className="flex flex-wrap items-center gap-2 text-sm text-foreground">
          {repeat === "every_n_months" && (
            <>
              <span>開始日の月から</span>
              <input
                type="number"
                aria-label="何ヶ月ごと"
                min="2"
                max={MAX_INTERVAL_COUNT}
                value={intervalCount}
                onChange={(e) => setIntervalCount(e.target.value)}
                required
                className={`${inputClass} w-16 text-right`}
              />
              <span>ヶ月ごとの</span>
            </>
          )}
          {repeat === "monthly" && <span>毎月</span>}
          {repeat === "yearly" && <span>毎年、開始日の月の</span>}
          {isWeekly ? (
            <>
              <input
                type="number"
                aria-label="何週ごと"
                min="1"
                max={MAX_INTERVAL_COUNT}
                value={weekInterval}
                onChange={(e) => setWeekInterval(e.target.value)}
                required
                className={`${inputClass} w-16 text-right`}
              />
              <span>週ごとの</span>
              <select
                aria-label="曜日"
                value={weekday}
                onChange={(e) => setWeekday(e.target.value)}
                className={`${inputClass} w-24`}
              >
                {WEEKDAY_NAMES.map((name, index) => (
                  <option key={name} value={index}>
                    {name}曜日
                  </option>
                ))}
              </select>
            </>
          ) : (
            <select
              aria-label="日"
              value={dayOfMonth}
              onChange={(e) => setDayOfMonth(e.target.value)}
              className={`${inputClass} w-24`}
            >
              {DAYS.map((day) => (
                <option key={day} value={day}>
                  {day} 日
                </option>
              ))}
              <option value={MONTH_END_DAY}>月末</option>
            </select>
          )}
        </div>
        <p className={noteClass}>
          {isWeekly
            ? "開始日から最初のその曜日が 1 回目です（隔週は 2 週ごと）。"
            : "月に無い日（2 月 30 日など）は月末になります。土日・祝日でもずらしません。"}
        </p>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <div className="flex flex-col gap-1.5">
          <label htmlFor="recurring-start" className={labelClass}>
            開始日
          </label>
          <input
            id="recurring-start"
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            required
            className={inputClass}
          />
        </div>
        <div className="flex flex-col gap-1.5">
          <label htmlFor="recurring-end" className={labelClass}>
            終了日（任意）
          </label>
          <input
            id="recurring-end"
            type="date"
            value={endDate}
            min={startDate}
            onChange={(e) => setEndDate(e.target.value)}
            className={inputClass}
          />
        </div>
      </div>
      <p className={noteClass}>
        開始日から後の回が「今月の決まった収支」に並びます。登録済みの月より前を開始日にすると、その月も未登録として出ます。
      </p>

      <div className="flex flex-col gap-1.5 rounded-lg bg-black/5 p-3 dark:bg-white/5">
        <span className="text-xs text-black/55 dark:text-white/55">次の予定日</span>
        {preview.length > 0 ? (
          <div className="flex flex-wrap gap-1.5">
            {preview.map((date) => (
              <span
                key={date}
                className="rounded-md border border-black/10 bg-white px-2 py-0.5 text-sm tabular-nums text-foreground dark:border-white/10 dark:bg-black/20"
              >
                {formatDate(date)}
              </span>
            ))}
          </div>
        ) : (
          <span className="text-sm text-black/55 dark:text-white/55">予定日はありません</span>
        )}
      </div>

      <div className="flex justify-end gap-2">
        <button type="button" onClick={onCancel} disabled={busy} className={buttonClass}>
          やめる
        </button>
        <button type="submit" disabled={busy || !countValid} className={primaryButtonClass}>
          {busy ? "保存中..." : entry ? "変更" : "追加"}
        </button>
      </div>
    </form>
  );
}
