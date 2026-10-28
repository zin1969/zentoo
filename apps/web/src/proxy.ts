import { NextResponse, type NextRequest } from "next/server";
import { TOKEN_COOKIE_NAME } from "@/lib/cookies/tokenCookieName";

// 未ログイン（トークン Cookie なし）で画面にアクセスした場合、ログイン画面へ遷移させる。
// Cookie の有無のみを見る簡易チェックであり、トークンの有効性は Rails が検証する（7.3章）。
// 期限切れなどで API が 401 を返した場合は、BFF が Cookie を破棄し、画面側がログイン画面へ遷移させる。
export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (pathname === "/login" || request.cookies.has(TOKEN_COOKIE_NAME)) {
    return NextResponse.next();
  }

  return NextResponse.redirect(new URL("/login", request.url));
}

export const config = {
  // API(BFF)・静的ファイルは対象外
  matcher: ["/((?!api|_next/static|_next/image|.*\\..*).*)"]
};
