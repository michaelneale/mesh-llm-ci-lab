//! The planner's stdout bytes: Python `json.dumps(plan, separators=(",",
//! ":"), sort_keys=True)` with the default `ensure_ascii`. `jq -c .` of these
//! bytes is what the protected caller hashes.

use std::fmt::Write;

/// `ensure_ascii` escaping: named escapes for `\" \\ \n \r \t \b \f`,
/// `\uXXXX` for other controls and every non-ASCII UTF-16 code unit.
pub fn write_string(out: &mut String, text: &str) {
    out.push('"');
    for ch in text.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{8}' => out.push_str("\\b"),
            '\u{c}' => out.push_str("\\f"),
            ' '..='~' => out.push(ch),
            _ => {
                let mut units = [0_u16; 2];
                for unit in ch.encode_utf16(&mut units) {
                    let _infallible = write!(out, "\\u{unit:04x}");
                }
            }
        }
    }
    out.push('"');
}
