import HomeLink from "../../../components/HomeLink";
import LogoutButton from "../../../components/LogoutButton";
import EditTransferJournal from "../../components/EditTransferJournal";

export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;

  return (
    <main className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <HomeLink />
        <LogoutButton />
      </div>
      <h1 className="text-xl font-semibold text-foreground">振替の修正</h1>
      <EditTransferJournal journalId={id} />
    </main>
  );
}
