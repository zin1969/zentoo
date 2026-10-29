import Link from "next/link";

export default function HomeLink() {
  return (
    <Link
      href="/"
      className="text-sm text-black/60 underline hover:text-black dark:text-white/60 dark:hover:text-white"
    >
      ← トップ
    </Link>
  );
}
