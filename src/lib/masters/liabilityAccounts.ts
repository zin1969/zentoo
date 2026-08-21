import { apiFetch } from "@/lib/api/apiFetch";

export type LiabilityAccount = {
  id: number;
  name: string;
  element_type: number;
  payment_method_type: number;
};

export async function getLiabilityAccounts() {
  return apiFetch<LiabilityAccount[]>("/accounts/liability-accounts");
}
