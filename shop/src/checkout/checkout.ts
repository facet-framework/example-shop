import { type Invoice, issueInvoice } from "../billing/invoice.ts";
import type { Customer } from "../customers/customer.ts";
import { type Cart, totalCents } from "./cart.ts";

export interface Order {
  id: string;
  customerId: string;
  placedAt: Date;
  totalCents: number;
  invoice: Invoice;
}

let nextOrder = 1;

export function placeOrder(cart: Cart, customer: Customer, now = new Date()): Order {
  const id = String(nextOrder++).padStart(6, "0");
  const total = totalCents(cart);
  return { id, customerId: customer.id, placedAt: now, totalCents: total, invoice: issueInvoice(id, customer, total, now) };
}
