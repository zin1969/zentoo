import OpeningAssetForm from "./components/OpeningAssetForm";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <h1 className="text-xl font-semibold text-foreground">開始資産登録</h1>
      <OpeningAssetForm />
    </main>
  );
}
