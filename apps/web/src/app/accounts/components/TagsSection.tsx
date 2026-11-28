"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/apiFetch";
import { deleteTag, getTags, updateTag, type Tag } from "@/lib/masters/tags";
import {
  buttonClass,
  dangerButtonClass,
  errorClass,
  inputClass,
  noteClass,
  primaryButtonClass,
  sectionClass
} from "./styles";

const MAX_NAME_LENGTH = 30;

function errorMessage(error: unknown) {
  if (error instanceof ApiError) {
    switch (error.data?.error) {
      case "duplicate_tag_name":
        return "同じ名前のタグがあります。";
      case "tag_not_found":
        return "タグが見つかりません。画面を再読み込みしてください。";
      case "tag_used_by_budget":
        return "予算の対象にしているタグは削除できません。先に「予算の設定」で予算を削除するか、対象を変えてください。";
    }

    if (error.data?.errors?.length) {
      return `名前を入力してください（${MAX_NAME_LENGTH} 文字まで）。`;
    }
  }

  return "保存に失敗しました。時間をおいて再度お試しください。";
}

type RenameFormProps = {
  tag: Tag;
  busy: boolean;
  onSubmit: (name: string) => void;
  onCancel: () => void;
};

function RenameForm({ tag, busy, onSubmit, onCancel }: RenameFormProps) {
  const [name, setName] = useState(tag.name);

  return (
    <form
      className="flex items-center gap-2"
      onSubmit={(e) => {
        e.preventDefault();
        onSubmit(name.trim());
      }}
    >
      <input
        type="text"
        aria-label="タグの名前"
        value={name}
        maxLength={MAX_NAME_LENGTH}
        onChange={(e) => setName(e.target.value)}
        required
        className={`${inputClass} flex-1`}
      />
      <button type="button" onClick={onCancel} disabled={busy} className={buttonClass}>
        やめる
      </button>
      <button type="submit" disabled={busy || !name.trim()} className={primaryButtonClass}>
        {busy ? "保存中..." : "保存"}
      </button>
    </form>
  );
}

// タグの一覧と、名前の変更・削除。タグはお買い物登録の画面で、その場で作る
export default function TagsSection() {
  const router = useRouter();
  const [tags, setTags] = useState<Tag[] | null>(null);
  const [reloadCount, setReloadCount] = useState(0);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    getTags()
      .then((data) => {
        if (!cancelled) setTags(data);
      })
      .catch((e) => {
        if (cancelled) return;

        if (e instanceof ApiError && e.status === 401) {
          router.replace("/login");
          return;
        }

        setError("タグの取得に失敗しました。時間をおいて再度お試しください。");
      });

    return () => {
      cancelled = true;
    };
  }, [reloadCount, router]);

  // 保存・削除をして、成功したら一覧を読み直す
  const run = async (action: () => Promise<unknown>, onSuccess?: () => void) => {
    setBusy(true);
    setError(null);

    try {
      await action();
      onSuccess?.();
      setReloadCount((n) => n + 1);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) {
        router.replace("/login");
        return;
      }

      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  // 使っているタグも削除できる。明細からタグが外れるだけで、明細は消えない
  const remove = (tag: Tag) => {
    const usage = tag.usage_count > 0 ? `\n${tag.usage_count} 件の明細からタグが外れます（明細は消えません）。` : "";
    if (!window.confirm(`タグ「${tag.name}」を削除しますか？${usage}`)) return;

    run(() => deleteTag(tag.id));
  };

  return (
    <section className={sectionClass}>
      <h2 className="text-base font-semibold text-foreground">タグ</h2>

      {error && <p className={errorClass}>{error}</p>}

      {tags === null ? (
        !error && <p className="text-sm text-black/50 dark:text-white/50">読み込み中...</p>
      ) : tags.length === 0 ? (
        <p className={noteClass}>タグはまだありません。</p>
      ) : (
        <ul className="flex flex-col divide-y divide-black/10 dark:divide-white/10">
          {tags.map((tag) => (
            <li key={tag.id} className="py-2.5">
              {editingId === tag.id ? (
                <RenameForm
                  tag={tag}
                  busy={busy}
                  onSubmit={(name) => run(() => updateTag(tag.id, name), () => setEditingId(null))}
                  onCancel={() => setEditingId(null)}
                />
              ) : (
                <div className="flex items-center gap-2">
                  <div className="flex min-w-0 flex-1 flex-col">
                    <span className="truncate text-sm text-foreground">#{tag.name}</span>
                    <span className={noteClass}>{tag.usage_count} 件の明細</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setError(null);
                      setEditingId(tag.id);
                    }}
                    disabled={busy}
                    className={buttonClass}
                  >
                    名前を変更
                  </button>
                  <button type="button" onClick={() => remove(tag)} disabled={busy} className={dangerButtonClass}>
                    削除
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}

      <p className={noteClass}>
        タグは「お買い物登録」の明細で、その場で作ります。名前を変えると、付いている明細のタグも新しい名前になります。
      </p>
    </section>
  );
}
