# zigeffect-transport

Real process-to-process ZigEffect cluster transport over bounded TCP framing.
The package owns client and server sockets and adapts the public
`ClusterTransport` request/response codec. TLS, peer identity, connection
pooling, discovery, and multi-process conformance are promoted only as their
live gates land; the descriptor remains honest while that work is incomplete.
