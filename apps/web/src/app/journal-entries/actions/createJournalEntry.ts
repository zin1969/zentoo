import { apiFetch } from "@/lib/api/apiFetch";

export async function createJournalEntry(body: any) {
  return apiFetch("/journal-entries", {
    method: "POST",
    body: body
  });
}
