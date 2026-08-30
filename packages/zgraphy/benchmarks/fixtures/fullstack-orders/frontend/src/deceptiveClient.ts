function createClient(service: unknown, transport: unknown) {
  return { getOrder: (_request: unknown) => ({ service, transport }) };
}

const OrdersService = {};
const transport = {};
const ordersClient = createClient(OrdersService, transport);

export function deceptiveFetch(id: string) {
  return ordersClient.getOrder({ id });
}
