function isSameOrigin(req: Request): boolean {
  const origin = req.headers.get("origin") ?? req.headers.get("referer");
  if (!origin) return false;

  try {
    return new URL(origin).origin === new URL(req.url).origin;
  } catch {
    return false;
  }
}

export function originGuardResponse(req: Request): Response | null {
  if (isSameOrigin(req)) return null;

  return Response.json({ error: "invalid_origin" }, { status: 403 });
}
