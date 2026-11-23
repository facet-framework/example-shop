export type ErrorCode = "E2001" | "E2002" | "E2003" | "E2004" | "E3001";

const messages: Record<ErrorCode, string> = {
  E2001: "Unknown discount code",
  E2002: "Discount code has expired",
  E2003: "Order value is below the code's minimum",
  E2004: "Only one discount code per order",
  E3001: "Refund window has closed",
};

export class ShopError extends Error {
  readonly code: ErrorCode;

  constructor(code: ErrorCode) {
    super(`${code}: ${messages[code]}`);
    this.code = code;
  }
}
