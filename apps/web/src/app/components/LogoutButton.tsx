"use client";

import { useRouter } from "next/navigation";
import { apiFetch } from "@/lib/api/apiFetch";

export default function LogoutButton() {
  const router = useRouter();

  const handleClick = async () => {
    await apiFetch("/logout", { method: "POST" }).catch(() => null);
    router.replace("/login");
  };

  return (
    <button
      type="button"
      onClick={handleClick}
      className="text-sm text-black/60 underline hover:text-black dark:text-white/60 dark:hover:text-white"
    >
      ログアウト
    </button>
  );
}
