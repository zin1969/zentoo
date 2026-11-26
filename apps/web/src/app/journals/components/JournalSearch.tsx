"use client";

import { useEffect, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { getAssetAccounts } from "@/lib/masters/assetAccounts";
import { getExpenseAccounts } from "@/lib/masters/expenseAccounts";
import { getLiabilityAccounts } from "@/lib/masters/liabilityAccounts";
import { getRevenueAccounts } from "@/lib/masters/revenueAccounts";
import { getTags, type Tag } from "@/lib/masters/tags";
import type { TwoLevelAccount } from "@/lib/masters/twoLevelAccounts";

// 仕訳一覧の検索の条件。科目は "element_type:account_id"、タグは ID の文字列（未指定は ""）
export type JournalSearchConditions = {
  q: string;
  accountKey: string;
  tagId: string;
};

export const EMPTY_CONDITIONS: JournalSearchConditions = { q: "", accountKey: "", tagId: "" };

export function hasConditions(conditions: JournalSearchConditions) {
  return conditions.q.trim() !== "" || conditions.accountKey !== "" || conditions.tagId !== "";
}

export function parseAccountKey(key: string) {
  const [elementType, accountId] = key.split(":").map(Number);
  if (!elementType || !accountId) return undefined;

  return { element_type: elementType, account_id: accountId };
}

const ASSET_ELEMENT_TYPE = 1;
const LIABILITY_ELEMENT_TYPE = 2;
const REVENUE_ELEMENT_TYPE = 4;
const EXPENSE_ELEMENT_TYPE = 5;

type AccountOption = { key: string; label: string };
type AccountGroup = { label: string; options: AccountOption[] };

// 親の科目のすぐ後に子科目を並べる（親を選ぶと子科目の仕訳も出る）
function twoLevelOptions(elementType: number, accounts: TwoLevelAccount[]): AccountOption[] {
  const parents = accounts.filter((a) => a.parent_id === null);

  return parents.flatMap((parent) => [
    { key: `${elementType}:${parent.id}`, label: parent.name },
    ...accounts
      .filter((a) => a.parent_id === parent.id)
      .map((child) => ({ key: `${elementType}:${child.id}`, label: `　└ ${child.name}` }))
  ]);
}

type Props = {
  conditions: JournalSearchConditions;
  onChange: (conditions: JournalSearchConditions) => void;
};

export default function JournalSearch({ conditions, onChange }: Props) {
  const router = useRouter();
  // キーワードは「検索」（または Enter）で確定する。入力のたびには読み込まない
  const [keyword, setKeyword] = useState(conditions.q);
  const [accountGroups, setAccountGroups] = useState<AccountGroup[]>([]);
  const [tags, setTags] = useState<Tag[]>([]);
  const [masterError, setMasterError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    Promise.all([getAssetAccounts(), getLiabilityAccounts(), getExpenseAccounts(), getRevenueAccounts(), getTags()])
      .then(([assets, liabilities, expenses, revenues, tagList]) => {
        if (cancelled) return;

        setAccountGroups([
          {
            label: "口座",
            options: assets.map((a) => ({ key: `${ASSET_ELEMENT_TYPE}:${a.id}`, label: a.name }))
          },
          {
            label: "カード等",
            options: liabilities.map((a) => ({ key: `${LIABILITY_ELEMENT_TYPE}:${a.id}`, label: a.name }))
          },
          { label: "費用科目", options: twoLevelOptions(EXPENSE_ELEMENT_TYPE, expenses) },
          { label: "収益科目", options: twoLevelOptions(REVENUE_ELEMENT_TYPE, revenues) }
        ]);
        setTags(tagList);
      })
      .catch((error) => {
        if (cancelled) return;

        if (error instanceof ApiError && error.status === 401) {
          router.replace("/login");
          return;
        }

        setMasterError("科目・タグの取得に失敗しました。キーワードだけで探せます。");
      });

    return () => {
      cancelled = true;
    };
  }, [router]);

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();
    onChange({ ...conditions, q: keyword });
  };

  const handleClear = () => {
    setKeyword("");
    onChange(EMPTY_CONDITIONS);
  };

  const fieldClass =
    "min-w-0 flex-1 rounded-md border border-black/15 px-3 py-2 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 dark:border-white/15 dark:bg-black/20";
  const buttonClass = "rounded-md border border-black/15 px-3 py-2 text-sm text-foreground dark:border-white/15";

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-2" role="search">
      <div className="flex items-center gap-2">
        <input
          type="search"
          aria-label="キーワード"
          placeholder="店舗名・品目・摘要"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          className={fieldClass}
        />
        <button type="submit" className={buttonClass}>
          検索
        </button>
      </div>

      <div className="flex items-center gap-2">
        <select
          aria-label="科目・口座"
          value={conditions.accountKey}
          onChange={(e) => onChange({ ...conditions, q: keyword, accountKey: e.target.value })}
          className={fieldClass}
        >
          <option value="">すべての科目・口座</option>
          {accountGroups
            .filter((group) => group.options.length > 0)
            .map((group) => (
              <optgroup key={group.label} label={group.label}>
                {group.options.map((option) => (
                  <option key={option.key} value={option.key}>
                    {option.label}
                  </option>
                ))}
              </optgroup>
            ))}
        </select>
        <select
          aria-label="タグ"
          value={conditions.tagId}
          onChange={(e) => onChange({ ...conditions, q: keyword, tagId: e.target.value })}
          className={fieldClass}
        >
          <option value="">すべてのタグ</option>
          {tags.map((tag) => (
            <option key={tag.id} value={String(tag.id)}>
              #{tag.name}
            </option>
          ))}
        </select>
      </div>

      {(hasConditions(conditions) || keyword !== "") && (
        <div className="flex justify-end">
          <button type="button" onClick={handleClear} className="text-sm text-blue-700 underline dark:text-blue-300">
            条件をクリア
          </button>
        </div>
      )}

      {masterError && <p className="text-sm text-red-700 dark:text-red-300">{masterError}</p>}
    </form>
  );
}
