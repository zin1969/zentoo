import HomeLink from "../components/HomeLink";
import LogoutButton from "../components/LogoutButton";
import AccountBalances from "./components/AccountBalances";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <h1 className="text-xl font-semibold text-foreground">残高</h1>
      <AccountBalances />
    </main>
  );
}
