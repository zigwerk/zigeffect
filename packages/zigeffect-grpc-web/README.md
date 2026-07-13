# @zigeffect/grpc-web

Generated Protobuf-ES v2 contracts and small framework-native helpers for Solid
applications. Connect owns RPC transport; `@tanstack/solid-query` owns caching,
cancellation and query lifecycle.

```ts
import { createClient } from "@connectrpc/connect";
import { createQuery } from "@tanstack/solid-query";
import {
  ConformanceService,
  connectUnaryQueryOptions,
  createZigEffectConnectTransport,
} from "@zigeffect/grpc-web";

const transport = createZigEffectConnectTransport({ baseUrl: "https://api.example.com" });
const client = createClient(ConformanceService, transport);

const result = createQuery(() => connectUnaryQueryOptions({
  serviceName: ConformanceService.typeName,
  methodName: "Unary",
  input: { id: "request-1", sequence: 1n },
  call: (input, signal) => client.unary(input, { signal }),
}));
```

Do not use the React-only Connect Query provider/hooks in Solid applications.
