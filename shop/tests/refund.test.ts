import assert from "node:assert/strict";
import { test } from "node:test";
import { addItem, emptyCart } from "../src/checkout/cart.ts";
import { placeOrder } from "../src/checkout/checkout.ts";
import { requestRefund } from "../src/orders/refund.ts";

const customer = { id: "c1", billingAddress: { name: "Ada", street: "Old Street 1", postalCode: "10115", city: "Berlin", country: "DE" } };
const order = placeOrder(addItem(emptyCart(), { sku: "MUG", unitPriceCents: 2000, quantity: 1 }), customer, new Date("2026-05-01T12:00:00Z"));

test("a refund within 30 days returns the order total", () => {
  assert.equal(requestRefund(order, new Date("2026-05-30T12:00:00Z")).amountCents, 2000);
});

test("a refund after 30 days is refused", () => {
  assert.throws(() => requestRefund(order, new Date("2026-06-01T12:00:00Z")), /E3001/);
});
