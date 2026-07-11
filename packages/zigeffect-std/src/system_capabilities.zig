const Capability = @import("capability/root.zig");

const conformance = Capability.Conformance{
    .schema = "zigeffect.system-primitives-conformance",
    .version = 1,
    .receipt = "conformance/system-primitives-live.v1.json",
    .authority = .live_external,
    .observed_at_ms = 1783777336000,
    .valid_until_ms = 1791553336000,
    .content_sha256 = "sha256:fddc0718cbc27865cde9292dddfd68e7ec0ba093c27954aa9242292001de4d49",
};

pub const layered_config = Capability.Descriptor{
    .id = "zigeffect-std.config.layered",
    .kind = .config,
    .maturity = .production_candidate,
    .package = "zigeffect-std",
    .version = "0.1.0",
    .features = &.{ "environment", "json-file", "layering", "provenance", "schema-decode", "explicit-reload" },
    .side_effects = .real,
    .conformance = conformance,
    .limitations = &.{ "file reload is explicit rather than watch based", "remote configuration providers are host supplied" },
};

pub const environment_secrets = Capability.Descriptor{
    .id = "zigeffect-std.secrets.environment",
    .kind = .secrets,
    .maturity = .production_candidate,
    .package = "zigeffect-std",
    .version = "0.1.0",
    .features = &.{ "references", "environment", "audit", "zeroization", "rotation-epoch", "boundary-redaction" },
    .side_effects = .real,
    .conformance = conformance,
    .limitations = &.{ "the environment provider reports process epoch one", "managed secret stores require a caller-owned Provider" },
};

test "system configuration and secret providers publish bounded production descriptors" {
    try layered_config.validate();
    try environment_secrets.validate();
}
