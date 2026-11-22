import { apiFetch } from "@/lib/api/apiFetch";

// 親子 2 階層の共通科目（費用科目・収益科目）
export type TwoLevelAccount = {
  id: number;
  name: string;
  // 親の科目の ID（トップレベルの科目は null）
  parent_id: number | null;
  // 仕訳で使われている。削除と親の付け替えができない
  in_use: boolean;
  // 子科目がある。削除できない
  has_children: boolean;
};

export type TwoLevelAccountInput = {
  name: string;
  parent_id: number | null;
};

export type TwoLevelAccountsApi = {
  list: () => Promise<TwoLevelAccount[]>;
  create: (input: TwoLevelAccountInput) => Promise<unknown>;
  update: (id: number, input: TwoLevelAccountInput) => Promise<unknown>;
  remove: (id: number) => Promise<void>;
};

// path は BFF のパス（例: "/accounts/expense-accounts"）
export function twoLevelAccountsApi(path: string): TwoLevelAccountsApi {
  return {
    list: () => apiFetch<TwoLevelAccount[]>(path),
    create: (input) => apiFetch<{ id: number }>(path, { method: "POST", body: input }),
    update: (id, input) => apiFetch<{ id: number }>(`${path}/${id}`, { method: "PUT", body: input }),
    remove: async (id) => {
      await apiFetch<null>(`${path}/${id}`, { method: "DELETE" });
    }
  };
}
