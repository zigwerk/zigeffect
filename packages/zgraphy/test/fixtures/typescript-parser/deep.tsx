import defaultTransport, {
  createClient as makeClient,
  type ClientOptions,
} from "@connectrpc/connect";
import * as Solid from "solid-js";
import legacy = require("./legacy");
import "./setup";

export interface Order {
  id: string;
  status: string;
}

export type OrderId = string;

export enum State {
  Ready,
  Loading,
}

export class OrdersController {
  constructor(private readonly client = ordersClient) {}

  async load(id: OrderId): Promise<Order> {
    return this.client.getOrder({ id });
  }
}

export const ordersClient = makeClient(defaultTransport);

export const fetchOrder = async (id: OrderId) => {
  const controller = new OrdersController();
  return controller.load(id);
};

export function OrderPage(props: { id: string }) {
  const resource = Solid.createResource(() => props.id, fetchOrder);
  void import("./lazy");
  const text = "function invented() { phantomCall(); }";
  return <p onClick={() => fetchOrder(props.id)}>{resource()?.status ?? text}</p>;
}

// export function commentedOut() { alsoPhantom(); }
