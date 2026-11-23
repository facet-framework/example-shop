# 4. Invoices copy the billing address

## Status

Accepted

## Context

An issued invoice is a legal document and may not change afterwards. Customers
change their billing address, for example when they move.

## Decision

When an invoice is issued, the customer's current billing address is copied into
the invoice row (`billing_name` to `billing_country`). The invoice does not
reference `customer_addresses`.

## Consequences

The address is stored twice. A later address change affects only invoices issued
after it. Normalizing the invoice columns into a reference would change every old
invoice and is not allowed.
