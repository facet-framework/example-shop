import { ShopError } from "../errors.ts";
import { type Cart, subtotalCents } from "./cart.ts";

export interface DiscountCode {
  code: string;
  percent: number;
  /** Last day the code is valid, as YYYY-MM-DD. */
  expiresOn: string;
  minimumOrderCents?: number;
}

export const discountCodes: DiscountCode[] = [
  { code: "SPRING5", percent: 5, expiresOn: "2026-05-31" },
  { code: "WELCOME10", percent: 10, expiresOn: "2099-12-31", minimumOrderCents: 5000 },
];

// The expiry day ends in UTC for every customer. Comparing against local
// midnight made codes expire a day early west of UTC (fixed in 2026-08).
function isExpired(code: DiscountCode, now: Date): boolean {
  return now.getTime() > Date.parse(`${code.expiresOn}T23:59:59.999Z`);
}

/** Redeems a code on a cart. Returns the new cart; throws a ShopError and leaves the cart unchanged otherwise. */
export function redeemDiscountCode(cart: Cart, input: string, now = new Date()): Cart {
  if (cart.discountCode) throw new ShopError("E2004");
  const code = discountCodes.find((c) => c.code === input.trim().toUpperCase());
  if (!code) throw new ShopError("E2001");
  if (isExpired(code, now)) throw new ShopError("E2002");
  const subtotal = subtotalCents(cart);
  if (code.minimumOrderCents !== undefined && subtotal < code.minimumOrderCents) throw new ShopError("E2003");
  return { ...cart, discountCode: code.code, discountCents: Math.round((subtotal * code.percent) / 100) };
}
