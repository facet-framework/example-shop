import { createServer } from "node:http";
import { requestRefund } from "./orders/refund.ts";
import { addItem, type Cart, emptyCart } from "./checkout/cart.ts";
import { type Order, placeOrder } from "./checkout/checkout.ts";
import { redeemDiscountCode } from "./checkout/discount.ts";
import { type Address, changeBillingAddress, type Customer } from "./customers/customer.ts";
import { ShopError } from "./errors.ts";

// One customer, one cart, orders in memory: enough to try the shop by hand.
let customer: Customer = {
  id: "c1",
  billingAddress: { name: "Ada", street: "Old Street 1", postalCode: "10115", city: "Berlin", country: "DE" },
};
let cart: Cart = emptyCart();
const orders = new Map<string, Order>();

type Handler = (body: any) => unknown;

const routes: Record<string, Handler> = {
  "POST /cart/items": (body) => (cart = addItem(cart, body)),
  "POST /cart/code": (body) => (cart = redeemDiscountCode(cart, String(body.code))),
  "PUT /customer/address": (body: Address) => (customer = changeBillingAddress(customer, body)),
  "POST /orders": () => {
    const order = placeOrder(cart, customer);
    orders.set(order.id, order);
    cart = emptyCart();
    return order;
  },
  "POST /refunds": (body) => {
    const order = orders.get(String(body.orderId));
    if (!order) return { error: "unknown order" };
    return requestRefund(order);
  },
};

const server = createServer(async (req, res) => {
  const handler = routes[`${req.method} ${req.url}`];
  if (!handler) {
    res.writeHead(404).end();
    return;
  }
  let raw = "";
  for await (const chunk of req) raw += chunk;
  try {
    const result = handler(raw ? JSON.parse(raw) : {});
    res.writeHead(200, { "content-type": "application/json" }).end(JSON.stringify(result));
  } catch (error) {
    if (!(error instanceof ShopError)) throw error;
    res.writeHead(422, { "content-type": "application/json" }).end(JSON.stringify({ error: error.code }));
  }
});

server.listen(Number(process.env.PORT ?? 3000));
