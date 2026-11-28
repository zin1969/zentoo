import Link from "next/link";
import LogoutButton from "./components/LogoutButton";

const MENU = [
  { href: "/journal-entries", title: "お買い物登録", description: "日々の支出を登録する" },
  { href: "/income-journals", title: "収入登録", description: "給料などの収入を、入金先の口座に登録する" },
  { href: "/recurring-entries", title: "決まった収支", description: "家賃・サブスク・給料・積立など、決まった支払い・収入・振替の今月の分を確かめて登録する" },
  { href: "/transfer-journals", title: "振替", description: "ATM での引き出し・預け入れ、口座間の振替、電子マネーへのチャージ、証券口座・iDeCo・NISA への積立を登録する" },
  { href: "/stock-trades", title: "株の売買", description: "現物株の買い・売りを、証券口座（預り金）との間で登録する。売りの損益は自動で計算する" },
  { href: "/journals", title: "仕訳一覧", description: "登録した仕訳を期間で確認する" },
  { href: "/account-balances", title: "残高", description: "口座・現金・カードの残高を確認する" },
  { href: "/bank-account-ledgers", title: "通帳", description: "預金口座の出入金と、これからの引き落とし予定を確認する" },
  { href: "/stock-holdings", title: "保有株", description: "銘柄ごとの株数・取得額・平均取得単価を確認する" },
  { href: "/monthly-expenses", title: "月次の収支", description: "月ごとの収入・支出を科目別に、収支と一緒に確認する" },
  { href: "/tag-reports", title: "タグの集計", description: "タグ（目的）ごとの支出を、1 年分の月ごとに確認する" },
  { href: "/asset-opening-journals", title: "開始資産登録", description: "口座・現金の開始残高と、今持っている株（株数と平均取得単価）を登録する" },
  { href: "/liability-opening-journals", title: "開始負債登録", description: "未払いのカードの残高を登録する" },
  { href: "/accounts", title: "口座・カード・科目・タグの管理", description: "口座・クレジットカード・費用科目・収益科目を追加・変更し、タグの名前を整理する" }
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
