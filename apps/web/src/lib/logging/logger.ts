type LogFields = Record<string, unknown>;

// Next.js Server-side ログ。Rails 側の X-Request-Id と突き合わせられるよう、
// 呼び出し元は fields.requestId を必ず渡すこと（12.2章）。
export function log(event: string, fields: LogFields = {}) {
  console.log(JSON.stringify({ event, ...fields }));
}
