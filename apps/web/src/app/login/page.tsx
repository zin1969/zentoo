import LoginForm from "./components/LoginForm";

export default function Page() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <h1 className="text-xl font-semibold text-foreground">ログイン</h1>
      <LoginForm />
    </main>
  );
}
