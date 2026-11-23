import assert from "node:assert/strict";
import { test } from "node:test";
import { issueInvoice } from "../src/billing/invoice.ts";
import { type Customer, changeBillingAddress } from "../src/customers/customer.ts";

const oldAddress = { name: "Ada", street: "Old Street 1", postalCode: "10115", city: "Berlin", country: "DE" };
const newAddress = { ...oldAddress, street: "New Street 2" };
const customer: Customer = { id: "c1", billingAddress: oldAddress };

test("an issued invoice keeps the address it was issued to", () => {
  const invoice = issueInvoice("000001", customer, 2000);
  changeBillingAddress(customer, newAddress);
  assert.equal(invoice.billingAddress.street, "Old Street 1");
});

test("the next invoice uses the current address", () => {
  const moved = changeBillingAddress(customer, newAddress);
  assert.equal(issueInvoice("000002", moved, 2000).billingAddress.street, "New Street 2");
});
