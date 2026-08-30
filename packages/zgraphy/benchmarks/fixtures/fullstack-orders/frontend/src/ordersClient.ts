import { createClient } from "@connectrpc/connect";
import { OrdersService } from "../gen/orders_pb";
import { transport } from "./transport";

export const ordersClient = createClient(OrdersService, transport);

export async function fetchOrder(id: string) {
  return ordersClient.getOrder({ id });
}
