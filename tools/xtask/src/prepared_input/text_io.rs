use std::path::Path;

pub(crate) fn os_error(path: &Path, error: &std::io::Error) -> String {
    format!("{}: {error}", path.display())
}
