import type { Address, Customer } from "../customers/customer.ts";

export interface Invoice {
  id: string;
  orderId: string;
  customerId: string;
  issuedAt: Date;
  totalCents: number;
  billingAddress: Address;
}

/** Issues an invoice and copies the customer's current billing address onto it. */
export function issueInvoice(orderId: string, customer: Customer, totalCents: number, now = new Date()): Invoice {
  return {
    id: `INV-${orderId}`,
    orderId,
    customerId: customer.id,
    issuedAt: now,
    totalCents,
    billingAddress: { ...customer.billingAddress },
  };
}
