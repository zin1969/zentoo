import { apiFetch } from "@/lib/api/apiFetch";

// 仕訳は作り直されるので、返る journal_id は新しい ID
export async function updateJournalEntry(id: number, body: unknown) {
  return apiFetch<{ journal_id: number }>(`/journal-entries/${id}`, {
    method: "PUT",
    body: body
  });
}
