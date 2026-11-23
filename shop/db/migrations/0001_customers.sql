CREATE TABLE customers (
  id UUID PRIMARY KEY
);

CREATE TABLE customer_addresses (
  id          UUID PRIMARY KEY,
  customer_id UUID NOT NULL REFERENCES customers(id),
  name        TEXT NOT NULL,
  street      TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  city        TEXT NOT NULL,
  country     CHAR(2) NOT NULL
);
