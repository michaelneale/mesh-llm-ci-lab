//! Path and error text in the form the packaging reports use.
use crate::repository::text::repr;
use std::path::Path;

/// `str(Path(text))` for a POSIX path: repeated separators and `.` parts
/// collapse and a trailing separator disappears.
pub fn python_path_display(path: &Path) -> String {
    let text = path.to_string_lossy();
    let parts = text
        .split('/')
        .filter(|part| !part.is_empty() && *part != ".")
        .collect::<Vec<_>>()
        .join("/");
    match (text.starts_with('/'), parts.is_empty()) {
        (true, _) => format!("/{parts}"),
        (false, true) => ".".to_owned(),
        (false, false) => parts,
    }
}

/// Python's `OSError.__str__` for a failed file read.
pub fn os_error_text(error: &std::io::Error, path: &str) -> String {
    let rendered = error.to_string();
    match error.raw_os_error() {
        Some(code) => {
            let suffix = format!(" (os error {code})");
            let reason = rendered.strip_suffix(&suffix).unwrap_or(&rendered);
            format!("[Errno {code}] {reason}: {}", repr(path))
        }
        None => rendered,
    }
}
