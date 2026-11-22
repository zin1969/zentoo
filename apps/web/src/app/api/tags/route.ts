// src/app/api/tags/route.ts

import { proxyAuthedGet } from "@/lib/rails/proxyAuthedGet";
import { proxyAuthedWrite } from "@/lib/rails/proxyAuthedWrite";

export async function GET() {
  return proxyAuthedGet("/tags", "tags");
}

export async function POST(req: Request) {
  return proxyAuthedWrite(req, "POST", "/tags", "create_tag");
}
