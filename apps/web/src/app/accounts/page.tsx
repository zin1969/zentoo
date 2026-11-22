import HomeLink from "../components/HomeLink";
import LogoutButton from "../components/LogoutButton";
import AssetAccountsSection from "./components/AssetAccountsSection";
import CreditCardsSection from "./components/CreditCardsSection";
import TagsSection from "./components/TagsSection";
import TwoLevelAccountsSection from "./components/TwoLevelAccountsSection";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <h1 className="text-xl font-semibold text-foreground">口座・カード・科目・タグの管理</h1>
      <AssetAccountsSection />
      <CreditCardsSection />
      <TwoLevelAccountsSection kind="expense" />
      <TwoLevelAccountsSection kind="revenue" />
      <TagsSection />
    </main>
  );
}
