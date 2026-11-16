use crate::repository::check_report::CheckReport;

pub(crate) fn error(usage: &str, prog: &str, message: &str) -> CheckReport {
    CheckReport {
        stdout: String::new(),
        stderr: format!("{usage}{prog}: error: {message}\n"),
        code: 2,
    }
}
