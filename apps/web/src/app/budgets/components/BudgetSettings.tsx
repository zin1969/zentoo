"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getExpenseAccounts } from "@/lib/masters/expenseAccounts";
import { getTags, type Tag } from "@/lib/masters/tags";
import type { TwoLevelAccount } from "@/lib/masters/twoLevelAccounts";
import {
  PERIODS,
  PERIOD_MONTH,
  PERIOD_WEEK,
  TARGET_EXPENSE_ACCOUNT,
  TARGET_TAG,
  createBudget,
  deleteBudget,
  getBudgets,
  updateBudget,
  type Budget
} from "@/lib/budgets/budgets";

const MAX_NAME_LENGTH = 30;
const MONTHS = Array.from({ length: 12 }, (_, i) => i + 1);

type FormState = {
  name: string;
  targetType: number;
  expenseAccountId: string;
  tagId: string;
  periodType: number;
  amount: string;
  // 月の予算で、1〜12 月の額を月ごとに決める
  monthly: boolean;
  monthlyAmounts: string[];
  excludedTagIds: number[];
};

const EMPTY_FORM: FormState = {
  name: "",
  targetType: TARGET_EXPENSE_ACCOUNT,
  expenseAccountId: "",
  tagId: "",
  periodType: PERIOD_WEEK,
  amount: "",
  monthly: false,
  monthlyAmounts: MONTHS.map(() => ""),
  excludedTagIds: []
};

function formFrom(budget: Budget): FormState {
  return {
    name: budget.name,
    targetType: budget.target_type,
    expenseAccountId: budget.expense_account_id ? String(budget.expense_account_id) : "",
    tagId: budget.tag_id ? String(budget.tag_id) : "",
    periodType: budget.period_type,
    amount: budget.monthly_amounts ? "" : String(budget.amount),
    monthly: budget.monthly_amounts !== null,
    monthlyAmounts: budget.monthly_amounts ? budget.monthly_amounts.map(String) : MONTHS.map(() => ""),
    excludedTagIds: budget.excluded_tags.map((tag) => tag.id)
  };
}

function formatYen(amount: number) {
  return `¥${amount.toLocaleString("ja-JP")}`;
}

// 親の科目のすぐ後に子科目を並べる（親の科目の予算には子科目も入る）
function accountOptions(accounts: TwoLevelAccount[]) {
  const byId = new Map(accounts.map((a) => [a.id, a]));
  const tops = accounts.filter((a) => a.parent_id === null || !byId.has(a.parent_id));

  return tops.flatMap((top) => [
    { id: top.id, label: top.name },
    ...accounts.filter((a) => a.parent_id === top.id).map((child) => ({ id: child.id, label: `　└ ${child.name}` }))
  ]);
}

function amountSummary(budget: Budget) {
  if (budget.monthly_amounts) {
    const total = budget.monthly_amounts.reduce((sum, a) => sum + a, 0);
    return `月ごと（年 ${formatYen(total)}）`;
  }

  return formatYen(budget.amount);
}

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "budget_not_found":
        return "予算が見つかりません。すでに削除されている可能性があります。";
      case "expense_account_not_found":
        return "費用科目が見つかりません。画面を再読み込みしてください。";
      case "tag_not_found":
        return "タグが見つかりません。画面を再読み込みしてください。";
    }

    if (error.data?.errors?.length) {
      return error.data.errors.join(" / ");
    }
  }

  return "保存に失敗しました。時間をおいて再度お試しください。";
}

// 予算の一覧と、追加・変更・削除
export default function BudgetSettings() {
  const router = useRouter();
  const [budgets, setBudgets] = useState<Budget[]>([]);
  const [expenseAccounts, setExpenseAccounts] = useState<TwoLevelAccount[]>([]);
  const [tags, setTags] = useState<Tag[]>([]);
  const [loaded, setLoaded] = useState(false);
  // null は追加、数値はその予算の変更
  const [editingId, setEditingId] = useState<number | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const handleError = useCallback(
    (e: unknown, fallback?: string) => {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }

      setError(fallback ?? errorMessage(e));
    },
    [router]
  );

  const reload = useCallback(
    () => getBudgets().then(setBudgets).catch((e) => handleError(e, "予算の取得に失敗しました。")),
    [handleError]
  );

  useEffect(() => {
    let cancelled = false;

    Promise.all([getBudgets(), getExpenseAccounts(), getTags()])
      .then(([budgetList, accounts, tagList]) => {
        if (cancelled) return;

        setBudgets(budgetList);
        setExpenseAccounts(accounts);
        setTags(tagList);
        setLoaded(true);
      })
      .catch((e) => {
        if (!cancelled) handleError(e, "予算・科目・タグの取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [handleError]);

  const update = (patch: Partial<FormState>) => setForm((current) => ({ ...current, ...patch }));

  const startEdit = (budget: Budget) => {
    setEditingId(budget.id);
    setForm(formFrom(budget));
    setError(null);
    setNotice(null);
  };

  const cancelEdit = () => {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setError(null);
  };

  const toggleExcludedTag = (id: number) => {
    update({
      excludedTagIds: form.excludedTagIds.includes(id)
        ? form.excludedTagIds.filter((tagId) => tagId !== id)
        : [...form.excludedTagIds, id]
    });
  };

  const isAccount = form.targetType === TARGET_EXPENSE_ACCOUNT;
  const usesMonthly = form.periodType === PERIOD_MONTH && form.monthly;
  const monthlyTotal = form.monthlyAmounts.reduce((sum, a) => sum + (Number(a) || 0), 0);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setNotice(null);

    const input = {
      name: form.name.trim(),
      target_type: form.targetType,
      expense_account_id: isAccount ? Number(form.expenseAccountId) : null,
      tag_id: isAccount ? null : Number(form.tagId),
      period_type: form.periodType,
      amount: usesMonthly ? 0 : Number(form.amount),
      monthly_amounts: usesMonthly ? form.monthlyAmounts.map((a) => Number(a)) : null,
      excluded_tag_ids: isAccount ? form.excludedTagIds : []
    };

    try {
      if (editingId === null) {
        await createBudget(input);
        setNotice("予算を追加しました。");
      } else {
        await updateBudget(editingId, input);
        setNotice("予算を変更しました。");
      }

      setEditingId(null);
      setForm(EMPTY_FORM);
      await reload();
    } catch (err) {
      handleError(err);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (budget: Budget) => {
    if (!window.confirm(`予算「${budget.name}」を削除しますか？（仕訳は変わりません）`)) return;

    setError(null);
    setNotice(null);

    try {
      await deleteBudget(budget.id);
      if (editingId === budget.id) cancelEdit();
      setNotice("予算を削除しました。");
      await reload();
    } catch (err) {
      handleError(err);
      await reload();
    }
  };

  const inputClass =
    "rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";
  const labelClass = "text-sm font-medium text-foreground";
  const hintClass = "text-xs text-black/50 dark:text-white/50";
  const segmentClass = (active: boolean) =>
    active
      ? "rounded-md bg-white px-3 py-1.5 text-sm font-medium text-foreground shadow-sm dark:bg-black/40"
      : "rounded-md px-3 py-1.5 text-sm text-black/60 dark:text-white/60";

  return (
    <div className="flex flex-col gap-6">
      {notice && (
        <p className="rounded-md bg-green-50 px-3 py-2 text-sm text-green-700 dark:bg-green-900/30 dark:text-green-300">
          {notice}
        </p>
      )}

      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700 dark:bg-red-900/30 dark:text-red-300">
          {error}
        </p>
      )}

      {loaded &&
        PERIODS.map((period) => {
          const list = budgets.filter((budget) => budget.period_type === period.value);

          return (
            <section key={period.value} className="flex flex-col gap-2">
              <h2 className="text-sm font-medium text-black/60 dark:text-white/60">{period.label}の予算</h2>
              {list.length === 0 ? (
                <p className="rounded-xl border border-dashed border-black/15 px-4 py-3 text-sm text-black/50 dark:border-white/15 dark:text-white/50">
                  ありません。
                </p>
              ) : (
                <ul className="flex flex-col divide-y divide-black/10 rounded-xl border border-black/10 bg-white shadow-sm dark:divide-white/10 dark:border-white/10 dark:bg-black/20">
                  {list.map((budget) => (
                    <li key={budget.id} className="flex flex-col gap-1.5 px-4 py-3">
                      <div className="flex items-baseline justify-between gap-2">
                        <span className="min-w-0 truncate text-sm font-medium">{budget.name}</span>
                        <span className="shrink-0 text-sm tabular-nums">{amountSummary(budget)}</span>
                      </div>
                      <span className={hintClass}>
                        {budget.target_type === TARGET_EXPENSE_ACCOUNT ? "科目" : "タグ"}: {budget.target_name}
                        {budget.excluded_tags.length > 0 &&
                          `（除く: ${budget.excluded_tags.map((tag) => tag.name).join("・")}）`}
                      </span>
                      <div className="flex justify-end gap-2">
                        <button
                          type="button"
                          onClick={() => startEdit(budget)}
                          className="rounded-md border border-black/15 px-3 py-1 text-sm dark:border-white/15"
                        >
                          変更
                        </button>
                        <button
                          type="button"
                          onClick={() => handleDelete(budget)}
                          className="rounded-md border border-red-300 px-3 py-1 text-sm text-red-700 dark:border-red-800 dark:text-red-300"
                        >
                          削除
                        </button>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          );
        })}

      <form
        onSubmit={handleSubmit}
        className="flex w-full flex-col gap-5 rounded-xl border border-black/10 bg-white p-6 shadow-sm dark:border-white/10 dark:bg-black/20"
      >
        <h2 className="text-base font-semibold">{editingId === null ? "予算を追加" : "予算を変更"}</h2>

        <div className="flex flex-col gap-1.5">
          <label htmlFor="budget-name" className={labelClass}>
            名前
          </label>
          <input
            id="budget-name"
            type="text"
            value={form.name}
            maxLength={MAX_NAME_LENGTH}
            placeholder="食費・アルコール・電気代など"
            onChange={(e) => update({ name: e.target.value })}
            required
            className={inputClass}
          />
        </div>

        <div className="flex flex-col gap-1.5">
          <span className={labelClass}>対象</span>
          <div className="grid grid-cols-2 gap-1 rounded-lg bg-black/5 p-1 dark:bg-white/10" role="radiogroup">
            <button
              type="button"
              role="radio"
              aria-checked={isAccount}
              onClick={() => update({ targetType: TARGET_EXPENSE_ACCOUNT })}
              className={segmentClass(isAccount)}
            >
              費用科目
            </button>
            <button
              type="button"
              role="radio"
              aria-checked={!isAccount}
              onClick={() => update({ targetType: TARGET_TAG })}
              className={segmentClass(!isAccount)}
            >
              タグ
            </button>
          </div>
        </div>

        {isAccount ? (
          <>
            <div className="flex flex-col gap-1.5">
              <label htmlFor="budget-account" className={labelClass}>
                費用科目
              </label>
              <select
                id="budget-account"
                value={form.expenseAccountId}
                onChange={(e) => update({ expenseAccountId: e.target.value })}
                required
                className={inputClass}
              >
                <option value="">科目を選択</option>
                {accountOptions(expenseAccounts).map((account) => (
                  <option key={account.id} value={account.id}>
                    {account.label}
                  </option>
                ))}
              </select>
              <span className={hintClass}>親の科目を選ぶと、子科目の支出も入ります。</span>
            </div>

            {tags.length > 0 && (
              <fieldset className="flex flex-col gap-1.5">
                <legend className={labelClass}>除くタグ（任意）</legend>
                <div className="flex flex-wrap gap-2">
                  {tags.map((tag) => (
                    <label
                      key={tag.id}
                      className="flex items-center gap-1.5 rounded-md border border-black/15 px-2.5 py-1 text-sm dark:border-white/15"
                    >
                      <input
                        type="checkbox"
                        checked={form.excludedTagIds.includes(tag.id)}
                        onChange={() => toggleExcludedTag(tag.id)}
                      />
                      {tag.name}
                    </label>
                  ))}
                </div>
                <span className={hintClass}>
                  選んだタグの付いた明細は、この予算に数えません（例: 食費からアルコールを外し、アルコールはタグの予算で見る）。
                </span>
              </fieldset>
            )}
          </>
        ) : (
          <div className="flex flex-col gap-1.5">
            <label htmlFor="budget-tag" className={labelClass}>
              タグ
            </label>
            <select
              id="budget-tag"
              value={form.tagId}
              onChange={(e) => update({ tagId: e.target.value })}
              required
              className={inputClass}
            >
              <option value="">タグを選択</option>
              {tags.map((tag) => (
                <option key={tag.id} value={tag.id}>
                  {tag.name}
                </option>
              ))}
            </select>
          </div>
        )}

        <div className="flex flex-col gap-1.5">
          <span className={labelClass}>周期</span>
          <div className="grid grid-cols-3 gap-1 rounded-lg bg-black/5 p-1 dark:bg-white/10" role="radiogroup">
            {PERIODS.map((period) => (
              <button
                key={period.value}
                type="button"
                role="radio"
                aria-checked={form.periodType === period.value}
                onClick={() => update({ periodType: period.value })}
                className={segmentClass(form.periodType === period.value)}
              >
                {period.label}
              </button>
            ))}
          </div>
          <span className={hintClass}>週は月曜〜日曜、年は 1 月〜12 月です。</span>
        </div>

        {form.periodType === PERIOD_MONTH && (
          <label className="flex items-center gap-2 text-sm text-foreground">
            <input type="checkbox" checked={form.monthly} onChange={(e) => update({ monthly: e.target.checked })} />
            月ごとに額を決める（電気代・ガス代など季節で変わるもの）
          </label>
        )}

        {usesMonthly ? (
          <div className="flex flex-col gap-1.5">
            <span className={labelClass}>月ごとの額</span>
            <div className="grid grid-cols-3 gap-2">
              {MONTHS.map((month, index) => (
                <label key={month} className="flex flex-col gap-1">
                  <span className={hintClass}>{month}月</span>
                  <input
                    type="number"
                    min="0"
                    step="1"
                    inputMode="numeric"
                    value={form.monthlyAmounts[index]}
                    onChange={(e) =>
                      update({
                        monthlyAmounts: form.monthlyAmounts.map((a, i) => (i === index ? e.target.value : a))
                      })
                    }
                    required
                    className={`${inputClass} w-full min-w-0 px-2 text-right`}
                  />
                </label>
              ))}
            </div>
            <span className={hintClass}>年の合計 {formatYen(monthlyTotal)}。同じ額を毎年くり返します。</span>
          </div>
        ) : (
          <div className="flex flex-col gap-1.5">
            <label htmlFor="budget-amount" className={labelClass}>
              {PERIODS.find((p) => p.value === form.periodType)?.label}の額
            </label>
            <div className="relative">
              <span className="pointer-events-none absolute inset-y-0 left-3 flex items-center text-sm text-black/40 dark:text-white/40">
                ¥
              </span>
              <input
                id="budget-amount"
                type="number"
                min="0"
                step="1"
                inputMode="numeric"
                value={form.amount}
                onChange={(e) => update({ amount: e.target.value })}
                required
                className={`${inputClass} w-full pl-7 text-right`}
              />
            </div>
          </div>
        )}

        <div className="flex gap-2">
          {editingId !== null && (
            <button
              type="button"
              onClick={cancelEdit}
              className="flex-1 rounded-md border border-black/15 px-4 py-2 text-sm dark:border-white/15"
            >
              やめる
            </button>
          )}
          <button
            type="submit"
            disabled={saving || !loaded}
            className="flex-1 rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {saving ? "保存中..." : editingId === null ? "追加" : "変更"}
          </button>
        </div>
      </form>
    </div>
  );
}
