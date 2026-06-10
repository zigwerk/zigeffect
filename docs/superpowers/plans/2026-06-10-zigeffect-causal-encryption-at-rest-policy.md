# zigeffect Causal Encryption At Rest Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic, record-only encryption-at-rest policy contract for retained zigeffect causal artifacts.

**Architecture:** Follow the existing production-hardening report pattern: a standalone Zig tool emits text and JSON for `zigeffect.causal.encryption-at-rest-policy.v1`, embeds its own tests, is wired into `build.zig`, registered in schema governance, and documented in the hardening docs. The branch defines key ownership, rotation, encrypted fixture metadata, and redaction ordering without encrypting or decrypting bytes.

**Tech Stack:** Zig standard library, zigeffect build system, existing causal production-hardening report conventions, Markdown docs.

---

## File Map

- Create `packages/zigeffect/tools/causal_encryption_at_rest_policy.zig`: deterministic report, JSON/text renderers, parse options, embedded tests.
- Create `packages/zigeffect/docs/encryption-at-rest-policy.md`: human guide for the policy contract.
- Modify `packages/zigeffect/build.zig`: add executable, build step, test step, and aggregate `zig build test` dependency.
- Modify `packages/zigeffect/tools/causal_schema_governance.zig`: add schema entry and update schema count/tests.
- Modify `packages/zigeffect/docs/schema-governance.md`: document the new schema.
- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`: mark encryption item delivered and advance next branch to alerting integrations.
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`: update ordering/status/recommendation wording.
- Modify `packages/zigeffect/docs/operations.md`: add command and policy boundary.
- Modify `packages/zigeffect/docs/roadmap.md`: record delivered policy and next lane.
- Modify `packages/zigeffect/docs/m9-completion-audit.md`: update current backlog recommendation wording.

### Task 1: Red Tests For Encryption Policy Report

**Files:**
- Create: `packages/zigeffect/tools/causal_encryption_at_rest_policy.zig`

- [ ] **Step 1: Create the failing test skeleton**

Create the file with tests that describe the desired public contract before adding implementations:

```zig
const std = @import("std");

test "encryption at rest policy metadata names schema source contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.encryption-at-rest-policy.v1", encryption_at_rest_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), encryption_at_rest_policy_schema_version);
    try expectSourceContract("zigeffect.causal.production-artifact-aggregation.v1");
    try expectSourceContract("zigeffect.causal.durable-production-retention.v1");
    try expectSourceContract("zigeffect.causal.artifact-access-control.v1");
    try std.testing.expectEqualStrings("start-alerting-integrations", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-alerting-integrations", recommended_next_branch);
}

test "encryption at rest policy preserves domains key owners rotation and negative fixtures" {
    try expectDomain("production-retained-bundle");
    try expectDomain("incident-restricted-bundle");
    try expectDomain("external-summary");
    try expectKeyOwner("release-owner");
    try expectKeyOwner("incident-owner");
    try expectKeyOwner("agent-readonly");
    try expectRotationReason("scheduled");
    try expectRotationReason("incident");
    try expectRotationReason("key-compromise");
    try expectFixtureField("key_id_ref");
    try expectFixtureField("encrypted_payload_ref");
    try expectFixtureField("plaintext_hash_ref");
    try expectRedactionRule("redact-before-encrypt");
    try expectNegativeFixture("encrypted-before-redaction-blocked");
    try expectNegativeFixture("agent-key-access-denied");
    try expectNonGoal("encryption implementation");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("production mutation authority");
}

test "encryption at rest policy text report includes boundaries" {
    const report = try formatEncryptionAtRestPolicyText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.encryption-at-rest-policy.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "encryption domains:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production-retained-bundle") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "redact-before-encrypt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "encryption implementation") != null);
}

test "encryption at rest policy json report is machine readable" {
    const report = try formatEncryptionAtRestPolicyJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.encryption-at-rest-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_contracts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"encryption_domains\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"encrypted_artifact_fixture\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"redaction_rules\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\"") != null);
}

test "encryption at rest policy parses text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-encryption-at-rest-policy"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format", "" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-encryption-at-rest-policy", "--json" }));
}
```

- [ ] **Step 2: Run the red test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_encryption_at_rest_policy.zig
```

Expected: FAIL with missing declarations such as `encryption_at_rest_policy_schema`, `OutputFormat`, and report formatter functions.

### Task 2: Implement The Policy Report

**Files:**
- Modify: `packages/zigeffect/tools/causal_encryption_at_rest_policy.zig`

- [ ] **Step 1: Add constants, structs, and policy arrays**

Add the implementation above the tests:

```zig
const std = @import("std");

pub const encryption_at_rest_policy_schema = "zigeffect.causal.encryption-at-rest-policy.v1";
pub const encryption_at_rest_policy_schema_version: u32 = 1;
pub const recommendation = "start-alerting-integrations";
pub const recommended_next_branch = "codex/zigeffect-causal-alerting-integrations";

const OutputFormat = enum { text, json };
const generated_by = "causal-encryption-at-rest-policy";

const EncryptionDomain = struct {
    id: []const u8,
    artifact_class: []const u8,
    required_state: []const u8,
    key_owner: []const u8,
    rotation_cadence: []const u8,
    sharing_posture: []const u8,
    retention_dependency: []const u8,
};

const KeyOwner = struct {
    role: []const u8,
    owns: []const u8,
    key_material_access: []const u8,
    approval_scope: []const u8,
};

const RotationPolicy = struct {
    domain: []const u8,
    cadence: []const u8,
    required_evidence: []const u8,
    failure_action: []const u8,
};

const FixtureField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const RedactionRule = struct {
    id: []const u8,
    order: []const u8,
    required: bool,
    failure_action: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const AuditRecordField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const source_contracts: []const []const u8 = &.{
    "zigeffect.causal.production-artifact-aggregation.v1",
    "zigeffect.causal.durable-production-retention.v1",
    "zigeffect.causal.artifact-access-control.v1",
};
```

Then define policy arrays with these exact minimum ids:

- `encryption_domains`: `local-private-cache`, `ci-retained-bundle`,
  `production-retained-bundle`, `incident-restricted-bundle`,
  `external-summary`.
- `key_owners`: `maintainer`, `release-owner`, `incident-owner`, `auditor`,
  `agent-readonly`.
- `rotation_reasons`: `scheduled`, `incident`, `key-compromise`,
  `policy-change`.
- `rotation_policies`: one policy for each encryption domain except
  `external-summary`, because summaries carry redacted metadata only.
- `encrypted_artifact_fixture_fields`: `bundle_id`, `source_contract_schema`,
  `encryption_domain`, `key_owner_role`, `key_id_ref`, `algorithm_family`,
  `nonce_ref`, `encrypted_payload_ref`, `plaintext_hash_ref`,
  `redaction_state`, `rotation_state`, `recovery_verification_command`,
  `mutation_authority`.
- `redaction_rules`: `redact-before-encrypt`, `encrypted-bytes-not-proof`,
  `decrypt-review-fails-closed`, `access-control-after-encryption`.
- `negative_fixtures`: `encrypted-before-redaction-blocked`,
  `missing-key-owner-blocked`, `stale-rotation-evidence-blocked`,
  `agent-key-access-denied`, `external-reviewer-raw-bundle-denied`,
  `encryption-approval-is-not-mutation-authority`.
- `audit_record_fields`: `audit_record_id`, `bundle_id`,
  `encryption_domain`, `key_owner_role`, `key_id_ref`,
  `rotation_state`, `redaction_state`, `source_contract_schema`,
  `verification_command`, `mutation_authority`.
- `authority_boundaries`: role labels are not identities; key ids are
  references, never key material; encryption policy does not grant mutation
  authority; durable evidence remains NenDB adapter only.
- `non_goals`: `encryption implementation`, `artifact decryption`,
  `key generation`, `KMS integration`, `identity provider integration`,
  `live RBAC enforcement`, `Cockroach adapter work`, `React workbench support`,
  `production mutation authority`.
- `verification_commands`: include the focused and broad verification commands
  from Task 7.

- [ ] **Step 2: Add parse, text, JSON, helper, and main functions**

Use the same helper style as `causal_durable_production_retention.zig`. The
functions must have these exact signatures:

```zig
fn usage() []const u8
fn parseOptions(args: []const []const u8) !OutputFormat
pub fn formatEncryptionAtRestPolicyText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8
pub fn formatEncryptionAtRestPolicyJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8
fn appendJsonStringProperty(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8, trailing: bool) std.mem.Allocator.Error!void
fn appendJsonBoolProperty(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: bool, trailing: bool) std.mem.Allocator.Error!void
fn appendJsonStringArrayProperty(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, values: []const []const u8, trailing: bool) std.mem.Allocator.Error!void
fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) std.mem.Allocator.Error!void
fn failUsage(err: anyerror) noreturn
pub fn main(init: std.process.Init) !void
```

The text report must print sections named:

```text
source contracts
encryption domains
key ownership
rotation policy
encrypted artifact fixture
redaction rules
negative fixtures
audit record fields
authority boundaries
non-goals
verification commands
```

The JSON report must include properties named:

```json
{
  "schema": "zigeffect.causal.encryption-at-rest-policy.v1",
  "schema_version": 1,
  "status": "current",
  "generated_by": "causal-encryption-at-rest-policy",
  "source_contracts": [],
  "recommendation": "start-alerting-integrations",
  "recommended_next_branch": "codex/zigeffect-causal-alerting-integrations",
  "encryption_domains": [],
  "key_ownership": [],
  "rotation_reasons": [],
  "rotation_policies": [],
  "encrypted_artifact_fixture": [],
  "redaction_rules": [],
  "negative_fixtures": [],
  "audit_record_fields": [],
  "authority_boundaries": [],
  "non_goals": [],
  "verification_commands": []
}
```

- [ ] **Step 3: Add expectation helpers**

Add helpers used by the tests:

```zig
fn expectSourceContract(schema: []const u8) !void
fn expectDomain(id: []const u8) !void
fn expectKeyOwner(role: []const u8) !void
fn expectRotationReason(reason: []const u8) !void
fn expectFixtureField(name: []const u8) !void
fn expectRedactionRule(id: []const u8) !void
fn expectNegativeFixture(id: []const u8) !void
fn expectNonGoal(value: []const u8) !void
```

- [ ] **Step 4: Run the green direct test**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_encryption_at_rest_policy.zig
```

Expected: PASS.

### Task 3: Wire The Build Step

**Files:**
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Run red build command**

Run:

```sh
cd packages/zigeffect
zig build causal-encryption-at-rest-policy
```

Expected: FAIL because the build step does not exist.

- [ ] **Step 2: Add the build target**

Near the other production-hardening report tools, add:

```zig
const causal_encryption_at_rest_policy_tool_module = b.createModule(.{
    .root_source_file = b.path("tools/causal_encryption_at_rest_policy.zig"),
    .target = target,
    .optimize = optimize,
});

const causal_encryption_at_rest_policy_tool = b.addExecutable(.{
    .name = "zigeffect-causal-encryption-at-rest-policy",
    .root_module = causal_encryption_at_rest_policy_tool_module,
});
const run_causal_encryption_at_rest_policy_tool = b.addRunArtifact(causal_encryption_at_rest_policy_tool);
if (b.args) |args| run_causal_encryption_at_rest_policy_tool.addArgs(args);
const causal_encryption_at_rest_policy_step = b.step("causal-encryption-at-rest-policy", "Print causal encryption-at-rest policy report");
causal_encryption_at_rest_policy_step.dependOn(&run_causal_encryption_at_rest_policy_tool.step);

const causal_encryption_at_rest_policy_tool_tests = b.addTest(.{
    .name = "zigeffect-causal-encryption-at-rest-policy-tests",
    .root_module = causal_encryption_at_rest_policy_tool_module,
});
const run_causal_encryption_at_rest_policy_tool_tests = b.addRunArtifact(causal_encryption_at_rest_policy_tool_tests);
test_step.dependOn(&run_causal_encryption_at_rest_policy_tool_tests.step);
```

- [ ] **Step 3: Run build target**

Run:

```sh
cd packages/zigeffect
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
```

Expected: both commands exit 0 and print text/JSON reports.

### Task 4: Register Schema Governance

**Files:**
- Modify: `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify: `packages/zigeffect/docs/schema-governance.md`

- [ ] **Step 1: Add failing schema-governance expectations**

Update tests first:

```zig
try std.testing.expectEqual(@as(usize, 42), entries.len);
try expectSchema(entries, "zigeffect.causal.encryption-at-rest-policy.v1");
```

Add text and JSON report expectations for the same schema.

- [ ] **Step 2: Run red governance command**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
```

Expected: FAIL because the schema count and new schema entry do not match yet.

- [ ] **Step 3: Add schema entry**

Add this entry in the Production Hardening section:

```zig
.{
    .schema = "zigeffect.causal.encryption-at-rest-policy.v1",
    .version = 1,
    .category = "production-hardening",
    .status = "current",
    .emitted_by = &.{"causal-encryption-at-rest-policy"},
    .consumed_by = &.{ "durable retention", "artifact access control", "future encrypted storage adapters", "agents" },
    .compatibility = &.{"record-only"},
    .governance_requirements = &.{ "encryption policy tests", "redaction interaction fixtures", "operations docs", "roadmap update" },
},
```

- [ ] **Step 4: Update docs**

Add an Official Schema Matrix entry in `schema-governance.md`:

```markdown
- `zigeffect.causal.encryption-at-rest-policy.v1`

The encryption-at-rest policy report is a record-only production hardening
contract. It defines encryption domains, key ownership, key rotation evidence,
encrypted artifact fixture metadata, redaction/encryption ordering, negative
fixtures, and audit fields for retained causal artifacts. It does not encrypt
or decrypt artifacts, manage keys, call KMS, enforce RBAC, or grant mutation
authority.
```

- [ ] **Step 5: Run green governance commands**

Run:

```sh
cd packages/zigeffect
zig build causal-schema-governance
zig build causal-schema-governance -- --format json
```

Expected: both exit 0 and include `zigeffect.causal.encryption-at-rest-policy.v1`.

### Task 5: Update Backlog And Roadmap Docs

**Files:**
- Modify: `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify: `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify: `packages/zigeffect/docs/operations.md`
- Modify: `packages/zigeffect/docs/roadmap.md`
- Modify: `packages/zigeffect/docs/m9-completion-audit.md`

- [ ] **Step 1: Update backlog tests first**

Change expected constants:

```zig
try std.testing.expectEqualStrings("start-alerting-integrations", recommendation);
try std.testing.expectEqualStrings("codex/zigeffect-causal-alerting-integrations", recommended_next_branch);
```

Update text and JSON report expectations for the recommended next branch.

- [ ] **Step 2: Run red backlog command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
```

Expected: FAIL because constants still point to encryption.

- [ ] **Step 3: Mark encryption delivered and advance recommendation**

In `causal_production_hardening_backlog.zig`:

```zig
pub const recommendation = "start-alerting-integrations";
pub const recommended_next_branch = "codex/zigeffect-causal-alerting-integrations";
```

Change the `encryption-at-rest-policy` item:

```zig
.status = "delivered",
.summary = "Defines record-only encryption-at-rest policy, key ownership, rotation evidence, encrypted artifact fixture metadata, and redaction ordering for retained causal artifacts.",
.evidence_sources = &.{
    "packages/zigeffect/tools/causal_encryption_at_rest_policy.zig",
    "packages/zigeffect/docs/encryption-at-rest-policy.md",
    "packages/zigeffect/docs/schema-governance.md",
},
```

Keep `alerting-integrations` as planned.

- [ ] **Step 4: Update docs**

Update `production-hardening-backlog.md`:

- order line `9. encryption-at-rest-policy delivered`;
- recommendation points to `codex/zigeffect-causal-alerting-integrations`;
- text says encryption policy is delivered but encryption implementation remains a non-goal.

Update `operations.md`:

- add the command:

```sh
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
```

- state that redaction must happen before encryption and this contract does not manage keys.

Update `roadmap.md`:

- add delivered bullet for `causal-encryption-at-rest-policy`;
- keep alerting integrations future.

Update `m9-completion-audit.md` if it names the current recommended branch.

- [ ] **Step 5: Run green backlog command**

Run:

```sh
cd packages/zigeffect
zig build causal-production-hardening-backlog
zig build causal-production-hardening-backlog -- --format json
```

Expected: both exit 0 and recommend `codex/zigeffect-causal-alerting-integrations`.

### Task 6: Create Policy Documentation

**Files:**
- Create: `packages/zigeffect/docs/encryption-at-rest-policy.md`

- [ ] **Step 1: Write the guide**

Create the doc with these sections:

```markdown
# zigeffect Causal Encryption At Rest Policy

## Command
## Source Contracts
## Policy Boundary
## Encryption Domains
## Key Ownership
## Rotation Evidence
## Encrypted Artifact Fixture
## Redaction Interaction
## Negative Fixtures
## Authority Boundaries
## Verification Suite
```

The doc must explicitly say:

- redaction runs before encryption;
- encryption does not make unsafe plaintext acceptable;
- key ids are references, never key material;
- the branch does not encrypt, decrypt, generate keys, call KMS, enforce RBAC,
  or grant mutation authority;
- durable evidence direction remains NenDB adapter only;
- React and Cockroach remain out of scope.

- [ ] **Step 2: Verify docs mention command and boundaries**

Run:

```sh
rg -n "causal-encryption-at-rest-policy|redaction.*before encryption|key material|Cockroach|React|mutation authority" packages/zigeffect/docs/encryption-at-rest-policy.md
```

Expected: each important boundary is present.

### Task 7: Format, Verify, And Commit

**Files:**
- All modified files

- [ ] **Step 1: Format Zig files**

Run:

```sh
cd packages/zigeffect
zig fmt tools/causal_encryption_at_rest_policy.zig tools/causal_schema_governance.zig tools/causal_production_hardening_backlog.zig build.zig
```

- [ ] **Step 2: Focused verification**

Run:

```sh
cd packages/zigeffect
zig test tools/causal_encryption_at_rest_policy.zig
zig build causal-encryption-at-rest-policy
zig build causal-encryption-at-rest-policy -- --format json
zig build causal-schema-governance
zig build causal-production-hardening-backlog
```

- [ ] **Step 3: Broad verification**

Run:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

- [ ] **Step 4: Stage only branch-owned files**

Do not stage unrelated existing dirty files:

- `docs/superpowers/specs/2026-06-09-zigeffect-causal-production-hardening-backlog-design.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

Stage:

```sh
git add docs/superpowers/specs/2026-06-10-zigeffect-causal-encryption-at-rest-policy-design.md docs/superpowers/plans/2026-06-10-zigeffect-causal-encryption-at-rest-policy.md packages/zigeffect/tools/causal_encryption_at_rest_policy.zig packages/zigeffect/docs/encryption-at-rest-policy.md packages/zigeffect/build.zig packages/zigeffect/tools/causal_schema_governance.zig packages/zigeffect/docs/schema-governance.md packages/zigeffect/tools/causal_production_hardening_backlog.zig packages/zigeffect/docs/production-hardening-backlog.md packages/zigeffect/docs/operations.md packages/zigeffect/docs/roadmap.md packages/zigeffect/docs/m9-completion-audit.md
```

- [ ] **Step 5: Commit**

Run:

```sh
git commit -m "feat(zigeffect): add encryption at rest policy"
```

## Self-Review

- Spec coverage: tasks cover the policy report, build target, schema governance, backlog status, docs, verification, and commit.
- Placeholder scan: the plan contains no placeholder markers and names exact files and commands.
- Type consistency: schema name is consistently `zigeffect.causal.encryption-at-rest-policy.v1`; build step is consistently `causal-encryption-at-rest-policy`; branch recommendation advances to `codex/zigeffect-causal-alerting-integrations`.
