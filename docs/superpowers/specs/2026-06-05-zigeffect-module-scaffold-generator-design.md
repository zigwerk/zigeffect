# zigeffect Module Scaffold Generator Design

Date: 2026-06-05

## Goal

Make the module/application pattern easier for future agents to start from by
adding a compile-checked scaffold generator.

## Design

Create `packages/zigeffect/tools/scaffold_module.zig`. It exposes
`renderModuleTemplate(allocator, module_name, service_name)` and a small CLI
that prints a module folder sketch. The template includes:

- `service.zig`
- `layer.zig`
- `effects.zig`
- `fixtures.zig`
- `<module>_test.zig`
- `README.md`

The generator is intentionally text-only and does not write files. Agents can
inspect or redirect the output, while repo tests only need to compile and assert
the rendered structure.

Wire the tool test into `zig build examples` so the example/catalog build covers
both the readiness example and the module scaffold generator.

## Non-Goals

- Do not add a file-writing generator yet.
- Do not invent project-specific domain code.
- Do not make this part of the runtime package API.

## Tests

Add a test in the tool file asserting the rendered template contains the module
name, service name, and expected file names.
