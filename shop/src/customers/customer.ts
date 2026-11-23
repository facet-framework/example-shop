export interface Address {
  name: string;
  street: string;
  postalCode: string;
  city: string;
  country: string;
}

export interface Customer {
  id: string;
  billingAddress: Address;
}

export function changeBillingAddress(customer: Customer, address: Address): Customer {
  return { ...customer, billingAddress: address };
}
