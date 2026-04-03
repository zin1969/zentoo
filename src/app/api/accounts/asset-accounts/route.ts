// src/app/api/accounts/asset-accounts/route.ts

export async function GET() {
  const res = await fetch("http://api:3000/asset-accounts");
  return Response.json(await res.json());
}
