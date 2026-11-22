import { apiFetch } from "@/lib/api/apiFetch";

// 明細に付ける「何のために使ったか」（勉強・娯楽など）。ユーザーごと
export type Tag = {
  id: number;
  name: string;
  // タグが付いている明細の数
  usage_count: number;
};

export async function getTags() {
  return apiFetch<Tag[]>("/tags");
}

export async function createTag(name: string) {
  return apiFetch<{ id: number; name: string }>("/tags", { method: "POST", body: { name } });
}

export async function updateTag(id: number, name: string) {
  return apiFetch<{ id: number; name: string }>(`/tags/${id}`, { method: "PUT", body: { name } });
}

// 使っているタグも削除できる。明細からタグが外れるだけで、明細は消えない
export async function deleteTag(id: number) {
  await apiFetch<null>(`/tags/${id}`, { method: "DELETE" });
}
