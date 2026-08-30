import { createResource } from "solid-js";
import { fetchOrder } from "./ordersClient";

export function OrderPage(props: { orderId: string }) {
  const [order] = createResource(() => props.orderId, fetchOrder);
  return <p>{order()?.status ?? "loading"}</p>;
}
