use std::io::{self, Write};

pub(crate) fn stderr() -> impl Write {
    io::stderr()
}
