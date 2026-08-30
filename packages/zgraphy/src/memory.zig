//! Forwards to zgdb's ownership boundary.
//!
//! These two functions moved into the database package with the storage engine
//! that uses them. Twenty-seven files in zgraphy import this path, and none of
//! them care where the helpers live — so the file stays and forwards rather
//! than churning every import to prove a point about layering.
//!
//! Explicit re-exports rather than a wildcard: if zgdb grows a helper that
//! zgraphy should not reach for, that has to be a decision here.

const zgdb = @import("zgdb");

pub const slice = zgdb.Memory.slice;
pub const copy = zgdb.Memory.copy;
