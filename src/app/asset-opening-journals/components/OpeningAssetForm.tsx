"use client";

import { useState } from "react";
import { createOpeningAsset } from "../actions/createOpeningAsset";
import { getAssetAccounts } from "@/lib/masters/assetAccounts";

export default function OpeningAssetForm() {
  const [journalDate, setJournalDate] = useState("");
  const [assetAccountId, setAssetAccountId] = useState("");
  const [amount, setAmount] = useState("");

  const assetAccounts = getAssetAccounts();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    await createOpeningAsset({
      journal_date: journalDate,
      asset_type: 1,
      asset_account_id: Number(assetAccountId),
      amount: Number(amount)
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <div>
        <label>日付</label>
        <input
          type="date"
          value={journalDate}
          onChange={(e) => setJournalDate(e.target.value)}
        />
      </div>

      <div>
        <label>勘定科目</label>
        <select
          value={assetAccountId}
          onChange={(e) => setAssetAccountId(e.target.value)}
        >
          <option value="">選択</option>
          {assetAccounts.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name}
            </option>
          ))}
        </select>
      </div>

      <div>
        <label>金額</label>
        <input
          type="number"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />
      </div>

      <button type="submit">登録</button>
    </form>
  );
}
