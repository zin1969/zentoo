function isSameOrigin(req: Request): boolean {
  const origin = req.headers.get("origin") ?? req.headers.get("referer");
  const host = req.headers.get("host");
  if (!origin || !host) return false;

  // req.url は Docker のポートフォワーディング等でコンテナ内部のポートに
  // 書き換わることがあり信頼できないため、Host ヘッダーと比較する。
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}

export function originGuardResponse(req: Request): Response | null {
  if (isSameOrigin(req)) return null;

  return Response.json({ error: "invalid_origin" }, { status: 403 });
}
