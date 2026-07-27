//! zgdb — a ZigEffect-native embedded graph database.
//!
//! Storage, adjacency, lexical postings and vectors. It knows nothing about
//! code: no symbols, no imports, no languages. What a node *means* is the
//! tenant's schema, and both tenants — zgraphy's repository graph and
//! zigeffect's causal execution forest — are schemas over this.
//!
//! Extracted from zgraphy rather than written fresh, because the layering was
//! already there and pointing the right way: `model.zig` imported `nendb.zig`
//! and never the reverse, so the storage engine had no dependency on the
//! semantics built above it. The package boundary makes that visible and keeps
//! it that way — a semantic type cannot leak downward without a build error.

pub const Memory = @import("memory.zig");
pub const Store = @import("nendb.zig");

test {
    // Zig collects tests only from the module under test, so a package whose
    // root does not reference its modules ships a green artifact over zero
    // tests. This has already happened once in this repository.
    _ = Memory;
    _ = Store;
}
