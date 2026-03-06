import { getToken, setToken } from "../cookies/tokenCookie";

export async function apiFetch(url: string, options: RequestInit) {
  const token = getToken();

  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json"
    }
  });

  const data = await res.json();

  if (res.status !== 401 && data.next_token) {
    setToken(data.next_token);
  }

  if (!res.ok) {
    throw data;
  }

  return data;
}
