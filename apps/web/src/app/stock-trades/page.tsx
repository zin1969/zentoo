import Link from "next/link";
import HomeLink from "../components/HomeLink";
import LogoutButton from "../components/LogoutButton";
import StockTradeForm from "./components/StockTradeForm";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <div className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold text-foreground">株の売買</h1>
        <Link href="/stock-holdings" className="text-sm text-blue-600 underline dark:text-blue-400">
          保有株を見る
        </Link>
      </div>
      <StockTradeForm />
    </main>
  );
}
