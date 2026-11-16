pub(crate) fn python_int_text(text: &str) -> Option<String> {
    text.parse::<i128>().ok().map(|number| number.to_string())
}
