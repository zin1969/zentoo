import Link from "next/link";
import HomeLink from "../components/HomeLink";
import LogoutButton from "../components/LogoutButton";
import StockHoldings from "./components/StockHoldings";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <div className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold text-foreground">保有株</h1>
        <Link href="/stock-trades" className="text-sm text-blue-600 underline dark:text-blue-400">
          売買を登録
        </Link>
      </div>
      <StockHoldings />
    </main>
  );
}
