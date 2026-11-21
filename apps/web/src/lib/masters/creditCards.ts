import { apiFetch } from "@/lib/api/apiFetch";

export type CreditCard = {
  id: number;
  name: string;
  // 引き落とし設定の無いカードは null（設定を登録するまで、カード払いの登録ができない）
  cutoff_day: number | null;
  payment_day: number | null;
  bank_account_id: number | null;
  bank_account_name: string | null;
  // 仕訳で使われている。削除できない
  in_use: boolean;
};

export type CreditCardInput = {
  name: string;
  cutoff_day: number;
  payment_day: number;
  bank_account_id: number;
};

export async function getCreditCards() {
  return apiFetch<CreditCard[]>("/accounts/credit-cards");
}

export async function createCreditCard(input: CreditCardInput) {
  return apiFetch<{ id: number }>("/accounts/credit-cards", { method: "POST", body: input });
}

export async function updateCreditCard(id: number, input: CreditCardInput) {
  return apiFetch<{ id: number }>(`/accounts/credit-cards/${id}`, { method: "PUT", body: input });
}

export async function deleteCreditCard(id: number) {
  await apiFetch<null>(`/accounts/credit-cards/${id}`, { method: "DELETE" });
}
