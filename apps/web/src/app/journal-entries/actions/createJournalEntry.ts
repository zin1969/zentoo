import { apiFetch } from "@/lib/api/apiFetch";

export async function createJournalEntry(body: unknown) {
  return apiFetch("/journal-entries", {
    method: "POST",
    body: body
  });
}
