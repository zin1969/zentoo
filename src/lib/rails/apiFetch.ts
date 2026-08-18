const RAILS_API_BASE_URL = process.env.RAILS_API_URL ?? "http://api:3000";

const IDEMPOTENT_METHODS = new Set(["GET", "HEAD"]);
const MAX_RETRIES = 2;
const RETRY_DELAY_MS = 200;

type ApiFetchOptions = {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
};

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Next.js (Server-side) -> Rails API の共通呼び出し口。
// GET/HEAD のみ自動リトライする。POST/PATCH/DELETE 等の非べき等な操作は、
// Rails 側で処理済みの可能性があるため自動リトライしない（12.1章）。
export async function apiFetch(
  path: string,
  options: ApiFetchOptions = {}
): Promise<Response> {
  const method = options.method ?? "GET";
  const isIdempotent = IDEMPOTENT_METHODS.has(method);
  const maxAttempts = isIdempotent ? MAX_RETRIES + 1 : 1;

  let lastError: unknown;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fetch(`${RAILS_API_BASE_URL}${path}`, {
        method,
        headers: {
          "Content-Type": "application/json",
          ...options.headers
        },
        body: options.body
      });
    } catch (error) {
      lastError = error;

      if (!isIdempotent || attempt === maxAttempts) break;

      await sleep(RETRY_DELAY_MS * attempt);
    }
  }

  throw lastError;
}
