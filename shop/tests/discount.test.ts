import assert from "node:assert/strict";
import { test } from "node:test";
import { addItem, emptyCart } from "../src/checkout/cart.ts";
import { redeemDiscountCode } from "../src/checkout/discount.ts";

const cart = addItem(emptyCart(), { sku: "MUG", unitPriceCents: 2000, quantity: 1 });

test("an expired code is refused and the cart keeps its price", () => {
  assert.throws(() => redeemDiscountCode(cart, "SPRING5", new Date("2026-06-01T00:00:00Z")), /E2002/);
  assert.equal(cart.discountCents, 0);
});

test("the last day ends in UTC", () => {
  const redeemed = redeemDiscountCode(cart, "SPRING5", new Date("2026-05-31T23:30:00-00:00"));
  assert.equal(redeemed.discountCents, 100);
});

test("a code below its minimum order value is refused", () => {
  assert.throws(() => redeemDiscountCode(cart, "WELCOME10", new Date("2026-05-01T12:00:00Z")), /E2003/);
});

test("only one code per order", () => {
  const big = addItem(emptyCart(), { sku: "LAMP", unitPriceCents: 6000, quantity: 1 });
  const redeemed = redeemDiscountCode(big, "WELCOME10", new Date("2026-05-01T12:00:00Z"));
  assert.throws(() => redeemDiscountCode(redeemed, "SPRING5", new Date("2026-05-01T12:00:00Z")), /E2004/);
});
