//! Strict bounded OIDC verification profile with an explicit ES256 or RS256
//! algorithm allowlist. ES256 is also used by the IAP specialization. Issuer,
//! audience, lifetime, subject, optional email, and rotating JWKS policy are
//! configurable.
const implementation = @import("iap.zig");

pub const Algorithm = implementation.Algorithm;
pub const Identity = implementation.Identity;
pub const JwksSource = implementation.JwksSource;
pub const Options = implementation.Options;
pub const Verifier = implementation.Verifier;
