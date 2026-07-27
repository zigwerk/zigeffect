//! Bounding and de-fanging text that came from an indexed repository before it
//! reaches an agent's context.
//!
//! Every label, path and snippet zgraphy renders was read out of somebody
//! else's source tree. A repository can therefore choose what bytes land in the
//! context window of the agent that asked the question: ANSI escapes that
//! rewrite what the user sees, carriage returns that overwrite a previous line,
//! or a newline followed by text shaped like zgraphy's own output claiming a
//! different result. None of that requires the agent to be credulous — it
//! requires only that we forward the bytes unchanged.
//!
//! So the rendering path forwards no byte it has not inspected. This is
//! deliberately not the secret redactor in `zigeffect_std`: that answers "may
//! this value be shown at all", and this answers "may these bytes steer a
//! terminal or a model". A value can be perfectly non-secret and still be an
//! injection vector.

const std = @import("std");

/// Longest rendered run of untrusted text. A symbol name beyond this is either
/// generated or hostile, and both are better truncated than forwarded.
pub const max_len = 256;

/// Written in place of a stripped control byte. A visible marker rather than a
/// silent deletion, so text engineered to read differently once its escapes are
/// removed cannot do so unnoticed.
pub const replacement = '?';

const ellipsis = "...";

/// Scratch for one sanitized value. Callers keep one per field they render.
pub const Buffer = [max_len + ellipsis.len]u8;

/// Return `text` with every control byte replaced and the length bounded,
/// written into `buffer`. Allocation-free and infallible: the rendering path
/// must not gain a new failure mode in order to become safe, or it will be
/// skipped somewhere under pressure.
pub fn clean(buffer: *Buffer, text: []const u8) []const u8 {
    const truncated = text.len > max_len;
    const source = if (truncated) text[0..max_len] else text;

    for (source, 0..) |byte, index| {
        // C0 controls and DEL. Everything an escape sequence needs to begin
        // lives here, as do the newline and carriage return that let untrusted
        // text forge a line of our own output. Bytes >= 0x80 are left alone:
        // they are UTF-8 continuation and lead bytes, and mangling them would
        // corrupt every non-ASCII identifier for no security gain.
        buffer[index] = if (byte < 0x20 or byte == 0x7f) replacement else byte;
    }
    if (!truncated) return buffer[0..source.len];

    @memcpy(buffer[max_len..][0..ellipsis.len], ellipsis);
    return buffer[0 .. max_len + ellipsis.len];
}

/// True when `clean` would alter `text`. For tests and for reporting, not for
/// deciding whether to sanitize — the answer to that is always yes.
pub fn wouldAlter(text: []const u8) bool {
    if (text.len > max_len) return true;
    for (text) |byte| if (byte < 0x20 or byte == 0x7f) return true;
    return false;
}
