CREATE TABLE invoices (
  id                  TEXT PRIMARY KEY,
  order_id            TEXT NOT NULL REFERENCES orders(id),
  customer_id         UUID NOT NULL REFERENCES customers(id),
  issued_at           TIMESTAMPTZ NOT NULL,
  total_cents         INTEGER NOT NULL,
  -- Copied from the customer's address when the invoice is issued.
  billing_name        TEXT NOT NULL,
  billing_street      TEXT NOT NULL,
  billing_postal_code TEXT NOT NULL,
  billing_city        TEXT NOT NULL,
  billing_country     CHAR(2) NOT NULL
);
