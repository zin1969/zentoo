import Link from "next/link";
import HomeLink from "../components/HomeLink";
import LogoutButton from "../components/LogoutButton";
import BudgetReportView from "./components/BudgetReportView";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <div className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold text-foreground">予算</h1>
        <Link href="/budgets/settings" className="text-sm text-blue-600 underline dark:text-blue-400">
          予算の設定
        </Link>
      </div>
      <BudgetReportView />
    </main>
  );
}
