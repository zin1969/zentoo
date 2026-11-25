import Link from "next/link";
import LogoutButton from "../../components/LogoutButton";
import RecurringEntrySettings from "../components/RecurringEntrySettings";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <Link
          href="/recurring-entries"
          className="text-sm text-black/60 underline hover:text-black dark:text-white/60 dark:hover:text-white"
        >
          ← 今月の決まった収支
        </Link>
        <LogoutButton />
      </div>
      <h1 className="text-xl font-semibold text-foreground">決まった収支の設定</h1>
      <RecurringEntrySettings />
    </main>
  );
}
