use super::AgentError;

/// Splits a command line like a POSIX shell would for simple cases:
/// whitespace separates words, single and double quotes group, backslash
/// escapes. No expansion of any kind.
pub fn split_args(line: &str) -> Result<Vec<String>, AgentError> {
    let mut words = Vec::new();
    let mut current = String::new();
    let mut in_word = false;
    let mut chars = line.chars();
    while let Some(c) = chars.next() {
        match c {
            '\'' => {
                in_word = true;
                loop {
                    match chars.next() {
                        Some('\'') => break,
                        Some(c) => current.push(c),
                        None => {
                            return Err(AgentError::InvalidArgs("unclosed single quote".into()));
                        }
                    }
                }
            }
            '"' => {
                in_word = true;
                loop {
                    match chars.next() {
                        Some('"') => break,
                        Some('\\') => current.push(chars.next().unwrap_or('\\')),
                        Some(c) => current.push(c),
                        None => {
                            return Err(AgentError::InvalidArgs("unclosed double quote".into()));
                        }
                    }
                }
            }
            '\\' => {
                in_word = true;
                current.push(chars.next().unwrap_or('\\'));
            }
            c if c.is_whitespace() => {
                if in_word {
                    words.push(std::mem::take(&mut current));
                    in_word = false;
                }
            }
            c => {
                in_word = true;
                current.push(c);
            }
        }
    }
    if in_word {
        words.push(current);
    }
    Ok(words)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn splits_words_and_quotes() {
        assert_eq!(
            split_args("--model x  -i").unwrap(),
            vec!["--model", "x", "-i"]
        );
        assert_eq!(
            split_args(r#"--name "two words" 'a b' c\ d"#).unwrap(),
            vec!["--name", "two words", "a b", "c d"]
        );
        assert_eq!(split_args("''").unwrap(), vec![""]);
        assert!(split_args("").unwrap().is_empty());
        assert!(split_args("'open").is_err());
    }
}
