# zgraphy M2 Zig parser boundary implementation plan

1. Add an M2 requirement, controlled Testing v2 scenario and parser-adversarial
   Zig fixture; capture the expected red result.
2. Implement `src/zig_parser.zig` around `std.zig.Ast` with bounded owned facts,
   exact spans and typed malformed-source rejection.
3. Add deterministic validation and result fingerprints.
4. Add a parity projection that compares parser labels/lines with v1 graph
   extraction on existing Zig fixtures.
5. Integrate parsed declarations/imports/calls behind `indexZigSource` while
   preserving stable graph identity and existing canonical receipts.
6. Remove scanner-only helpers only after full Debug/ReleaseSafe, differential,
   safety and agent checks pass.

