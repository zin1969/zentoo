import HomeLink from "../components/HomeLink";
import LogoutButton from "../components/LogoutButton";
import OpeningLiabilityForm from "./components/OpeningLiabilityForm";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <h1 className="text-xl font-semibold text-foreground">開始負債登録</h1>
      <p className="text-sm text-black/60 dark:text-white/60">
        開始時点で未払いのカードの残高を登録します。引き落とし日が違う未払いは、日付ごとに分けて登録してください。
      </p>
      <OpeningLiabilityForm />
    </main>
  );
}
