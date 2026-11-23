import { ShopError } from "../errors.ts";
import type { Order } from "../checkout/checkout.ts";

export const refundWindowDays = 30;

export function requestRefund(order: Order, now = new Date()): { orderId: string; amountCents: number } {
  const deadline = order.placedAt.getTime() + refundWindowDays * 24 * 60 * 60 * 1000;
  if (now.getTime() > deadline) throw new ShopError("E3001");
  return { orderId: order.id, amountCents: order.totalCents };
}
