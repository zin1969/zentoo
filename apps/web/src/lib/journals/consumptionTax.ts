// 外税のレシートの消費税の計算。
// レシートと同じく、消費税は明細ごとではなく税率ごとの合計に対して計算し、端数は切り捨てる。
// 計算した消費税は、明細の税抜の金額の比で割り振り、各明細を税込の金額にする。

export type TaxLine = {
  key: string;
  taxExcludedAmount: number;
  // 整数の %
  taxRate: number;
};

export type TaxGroup = {
  rate: number;
  // 税抜の小計
  subtotal: number;
  // 小計 × 税率（切り捨て）
  defaultTax: number;
  // 実際に使う消費税（手で直していれば、その値）
  tax: number;
};

export type TaxResult = {
  groups: TaxGroup[];
  // 明細ごとの税込の金額
  amounts: Map<string, number>;
  total: number;
};

export function defaultTax(subtotal: number, rate: number) {
  return Math.floor((subtotal * rate) / 100);
}

// overrides: 税率ごとに手で直した消費税（直していない税率は入れない）
export function calculateTax(lines: TaxLine[], overrides: Map<number, number> = new Map()): TaxResult {
  const rates = [...new Set(lines.map((line) => line.taxRate))].sort((a, b) => b - a);
  const amounts = new Map<string, number>();

  const groups = rates.map((rate) => {
    const groupLines = lines.filter((line) => line.taxRate === rate);
    const subtotal = groupLines.reduce((sum, line) => sum + line.taxExcludedAmount, 0);
    const calculated = defaultTax(subtotal, rate);
    const tax = subtotal > 0 ? (overrides.get(rate) ?? calculated) : 0;

    // 税抜の金額の比で割り振り、割り切れない端数は金額のいちばん大きい明細に足す
    const shares = groupLines.map((line) => (subtotal > 0 ? Math.floor((tax * line.taxExcludedAmount) / subtotal) : 0));
    const remainder = tax - shares.reduce((sum, share) => sum + share, 0);
    const largest = groupLines.reduce(
      (best, line, index) => (line.taxExcludedAmount > groupLines[best].taxExcludedAmount ? index : best),
      0
    );

    groupLines.forEach((line, index) => {
      amounts.set(line.key, line.taxExcludedAmount + shares[index] + (index === largest ? remainder : 0));
    });

    return { rate, subtotal, defaultTax: calculated, tax };
  });

  const total = [...amounts.values()].reduce((sum, amount) => sum + amount, 0);

  return { groups, amounts, total };
}
