import Link from "next/link";
import LogoutButton from "./components/LogoutButton";

const MENU = [
  { href: "/journal-entries", title: "お買い物登録", description: "日々の支出を登録する" },
  { href: "/cash-deposit-journals", title: "現金の預け入れ", description: "現金を預金口座に預け入れた仕訳を登録する" },
  { href: "/journals", title: "仕訳一覧", description: "登録した仕訳を期間で確認する" },
  { href: "/account-balances", title: "残高", description: "口座・現金・カードの残高を確認する" },
  { href: "/monthly-expenses", title: "月次の支出", description: "月ごとの支出を科目別に確認する" },
  { href: "/asset-opening-journals", title: "開始資産登録", description: "口座・現金の開始残高を登録する" }
];

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <h1 className="text-xl font-semibold text-foreground">Zentoo</h1>
        <LogoutButton />
      </div>

      <nav>
        <ul className="flex flex-col gap-3">
          {MENU.map((item) => (
            <li key={item.href}>
              <Link
                href={item.href}
                className="flex flex-col gap-0.5 rounded-xl border border-black/10 bg-white px-4 py-3 shadow-sm transition-colors hover:border-blue-500 dark:border-white/10 dark:bg-black/20"
              >
                <span className="text-base font-medium text-foreground">{item.title}</span>
                <span className="text-sm text-black/60 dark:text-white/60">{item.description}</span>
              </Link>
            </li>
          ))}
        </ul>
      </nav>
    </main>
  );
}
