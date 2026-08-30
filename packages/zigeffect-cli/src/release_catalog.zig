const zstd = @import("zigeffect_std");

/// The release packager replaces this development placeholder in the staged
/// CLI archive after every dependency archive has an immutable URL and hash.
pub const embedded = zstd.Project.DependencyRelease{
    .version = "0.0.0-development",
    .packages = &.{},
};

pub fn available() bool {
    return embedded.packages.len != 0;
}
