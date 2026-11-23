CREATE TABLE orders (
  id          TEXT PRIMARY KEY,
  customer_id UUID NOT NULL REFERENCES customers(id),
  placed_at   TIMESTAMPTZ NOT NULL,
  total_cents INTEGER NOT NULL
);
