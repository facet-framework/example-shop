export interface CartItem {
  sku: string;
  unitPriceCents: number;
  quantity: number;
}

export interface Cart {
  items: CartItem[];
  discountCode?: string;
  discountCents: number;
}

export function emptyCart(): Cart {
  return { items: [], discountCents: 0 };
}

export function addItem(cart: Cart, item: CartItem): Cart {
  return { ...cart, items: [...cart.items, item] };
}

export function subtotalCents(cart: Cart): number {
  return cart.items.reduce((sum, item) => sum + item.unitPriceCents * item.quantity, 0);
}

export function totalCents(cart: Cart): number {
  return Math.max(0, subtotalCents(cart) - cart.discountCents);
}
