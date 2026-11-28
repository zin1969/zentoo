import HomeLink from "../components/HomeLink";
import LogoutButton from "../components/LogoutButton";
import JournalList from "./components/JournalList";

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

// 予算の画面などから、期間・科目（"element_type:account_id"）・タグを指定して開ける（初期の条件として使う）
export default async function Page({ searchParams }: { searchParams: SearchParams }) {
  const params = await searchParams;
  const text = (key: string) => (typeof params[key] === "string" ? (params[key] as string) : "");

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <h1 className="text-xl font-semibold text-foreground">仕訳一覧</h1>
      <JournalList initial={{ from: text("from"), to: text("to"), accountKey: text("account"), tagId: text("tag") }} />
    </main>
  );
}
