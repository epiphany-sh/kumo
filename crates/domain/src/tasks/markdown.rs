//! Task checkboxes in Markdown notes (`- [ ] Call Ana 📅 2026-11-02 #work`),
//! with the Obsidian Tasks plugin's emoji metadata.

use std::collections::HashMap;

use super::{Priority, TaskStatus};

/// One checkbox line of a note.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Checkbox {
    /// Zero-based line number.
    pub line: usize,
    /// Stable while the line's text doesn't change, wherever it moves.
    pub id: String,
    pub status: TaskStatus,
    /// The text without metadata, tags or link syntax.
    pub title: String,
    pub priority: Priority,
    /// `YYYY-MM-DD`.
    pub due: Option<String>,
    pub tags: Vec<String>,
}

/// Every checkbox outside code blocks, in order.
pub fn parse_checkboxes(text: &str) -> Vec<Checkbox> {
    let mut seen = HashMap::new();
    lines(text)
        .filter_map(|(line, _, raw)| {
            let found = find_checkbox(raw)?;
            let body = raw[found.body..].trim();
            if body.is_empty() {
                return None;
            }
            let id = checkbox_id(identity(body), &mut seen);
            Some(parse_body(line, id, status_of(found.mark), body))
        })
        .collect()
}

/// Rewrites the mark of checkbox `id` so it reads `status`. `None` if the
/// checkbox is gone (or `status` has no mark: review).
pub fn set_checkbox(text: &str, id: &str, status: TaskStatus) -> Option<String> {
    let mark = match status {
        TaskStatus::Todo => ' ',
        TaskStatus::Doing => '/',
        TaskStatus::Done => 'x',
        TaskStatus::Review => return None,
    };
    let mut seen = HashMap::new();
    for (_, start, raw) in lines(text) {
        let Some(found) = find_checkbox(raw) else {
            continue;
        };
        let body = raw[found.body..].trim();
        if body.is_empty() || checkbox_id(identity(body), &mut seen) != id {
            continue;
        }
        if status_of(found.mark) == status {
            return Some(text.to_owned());
        }
        let at = start + found.mark_at;
        let mut out = String::with_capacity(text.len());
        out.push_str(&text[..at]);
        out.push(mark);
        out.push_str(&text[at + found.mark.len_utf8()..]);
        return Some(out);
    }
    None
}

/// Notes without headings can be long: the section is cut to this many
/// lines on each side of the checkbox.
const SECTION_REACH: usize = 40;

/// The section of a note that holds zero-based `line`: from the closest
/// heading above it to the next heading of the same or a higher level (the
/// whole note when it has none), so a checkbox reads with its context.
pub fn section_around(text: &str, line: usize) -> String {
    let all: Vec<&str> = text
        .split('\n')
        .map(|l| l.strip_suffix('\r').unwrap_or(l))
        .collect();
    if line >= all.len() {
        return String::new();
    }
    let mut fenced = false;
    let levels: Vec<Option<usize>> = all
        .iter()
        .map(|l| {
            let trimmed = l.trim_start();
            if trimmed.starts_with("```") || trimmed.starts_with("~~~") {
                fenced = !fenced;
                return None;
            }
            if fenced {
                return None;
            }
            heading_level(l)
        })
        .collect();
    let (start, level) = (0..=line)
        .rev()
        .find_map(|n| levels[n].map(|level| (n, level)))
        .unwrap_or((0, 0));
    let end = (line + 1..all.len())
        .find(|n| levels[*n].is_some_and(|l| level > 0 && l <= level))
        .unwrap_or(all.len());
    let from = start.max(line.saturating_sub(SECTION_REACH));
    let to = end.min(line + SECTION_REACH + 1);
    let mut section: Vec<&str> = all[from..to].to_vec();
    if from > start && levels[start].is_some() {
        section.insert(0, all[start]);
    }
    while section.last().is_some_and(|l| l.trim().is_empty()) {
        section.pop();
    }
    let skip = section.iter().take_while(|l| l.trim().is_empty()).count();
    section[skip..].join("\n")
}

/// `## Title` → 2.
fn heading_level(line: &str) -> Option<usize> {
    let hashes = line.len() - line.trim_start_matches('#').len();
    let rest = &line[hashes..];
    ((1..=6).contains(&hashes) && (rest.is_empty() || rest.starts_with([' ', '\t'])))
        .then_some(hashes)
}

/// The part of a checkbox that identifies it: its text without metadata, so
/// completing it (which adds `✅ <date>`) or changing its due date keeps it.
fn identity(body: &str) -> &str {
    match body.find(SIGNIFIERS) {
        Some(at) if !body[..at].trim().is_empty() => body[..at].trim(),
        _ => body,
    }
}

/// FNV-1a of the text (stable across runs and versions), plus the
/// occurrence for repeated lines.
fn checkbox_id(body: &str, seen: &mut HashMap<u64, usize>) -> String {
    let hash = body.bytes().fold(0xcbf2_9ce4_8422_2325_u64, |h, b| {
        (h ^ u64::from(b)).wrapping_mul(0x0100_0000_01b3)
    });
    let n = seen.entry(hash).or_insert(0);
    *n += 1;
    match *n {
        1 => format!("{hash:016x}"),
        n => format!("{hash:016x}-{n}"),
    }
}

/// Lines outside fenced code blocks: number, byte offset, text.
fn lines(text: &str) -> impl Iterator<Item = (usize, usize, &str)> {
    let mut fence: Option<&str> = None;
    let mut next = 0;
    let numbered = text.split('\n').enumerate().map(move |(n, line)| {
        let start = next;
        next += line.len() + 1;
        (n, start, line)
    });
    numbered.filter(move |(_, _, line)| {
        let trimmed = line.trim_start();
        for marker in ["```", "~~~"] {
            if trimmed.starts_with(marker) {
                match fence {
                    None => fence = Some(marker),
                    Some(open) if open == marker => fence = None,
                    Some(_) => {}
                }
                return false;
            }
        }
        fence.is_none()
    })
}

struct Found {
    mark: char,
    /// Byte offset of the mark in the line.
    mark_at: usize,
    /// Byte offset where the task text starts.
    body: usize,
}

/// `- [ ] text`, `* [x] text`, `1. [/] text`, indented or quoted.
fn find_checkbox(line: &str) -> Option<Found> {
    let line = line.strip_suffix('\r').unwrap_or(line);
    let mut rest = line.trim_start_matches([' ', '\t', '>']);
    let bullet = if let Some(after) = rest.strip_prefix(['-', '*', '+']) {
        after
    } else {
        let digits = rest.len() - rest.trim_start_matches(|c: char| c.is_ascii_digit()).len();
        if digits == 0 {
            return None;
        }
        rest[digits..].strip_prefix(['.', ')'])?
    };
    rest = bullet
        .strip_prefix([' ', '\t'])?
        .trim_start_matches([' ', '\t']);
    let inner = rest.strip_prefix('[')?;
    let mark = inner.chars().next()?;
    let after = inner[mark.len_utf8()..].strip_prefix(']')?;
    if !(after.is_empty() || after.starts_with([' ', '\t'])) {
        return None;
    }
    let mark_at = line.len() - inner.len();
    Some(Found {
        mark,
        mark_at,
        body: line.len() - after.len(),
    })
}

fn status_of(mark: char) -> TaskStatus {
    match mark {
        'x' | 'X' | '-' => TaskStatus::Done,
        '/' => TaskStatus::Doing,
        _ => TaskStatus::Todo,
    }
}

/// Emoji that start the Tasks plugin's metadata.
const SIGNIFIERS: &[char] = &[
    '🔺', '⏫', '🔼', '🔽', '⏬', '📅', '📆', '🗓', '⏳', '⌛', '🛫', '➕', '✅', '❌', '🔁', '🆔',
    '⛔',
];

fn parse_body(line: usize, id: String, status: TaskStatus, body: &str) -> Checkbox {
    let (text, meta) = match body.find(SIGNIFIERS) {
        Some(at) => body.split_at(at),
        None => (body, ""),
    };
    let priority = meta
        .chars()
        .find_map(|c| match c {
            '🔺' => Some(Priority::Urgent),
            '⏫' => Some(Priority::High),
            '🔼' => Some(Priority::Medium),
            '🔽' | '⏬' => Some(Priority::Low),
            _ => None,
        })
        .unwrap_or_default();
    let due = ['📅', '📆', '🗓'].iter().find_map(|emoji| {
        let after = &meta[meta.find(*emoji)? + emoji.len_utf8()..];
        let date = after.trim_start_matches(['\u{fe0f}', ' ']).get(..10)?;
        is_date(date).then(|| date.to_owned())
    });
    let mut tags = Vec::new();
    let mut words = Vec::new();
    for word in unlink(text).split_whitespace() {
        match word.strip_prefix('#') {
            Some(tag) if tag.chars().next().is_some_and(|c| c.is_alphabetic()) => {
                tags.push(tag.trim_end_matches(['#', ',', '.']).to_owned());
            }
            _ => words.push(word.to_owned()),
        }
    }
    // Tags often go at the end, after the metadata.
    tags.extend(meta.split_whitespace().filter_map(|word| {
        let tag = word.strip_prefix('#')?;
        tag.chars()
            .next()
            .is_some_and(|c| c.is_alphabetic())
            .then(|| tag.trim_end_matches(['#', ',', '.']).to_owned())
    }));
    let title = if words.is_empty() {
        body.trim().to_owned()
    } else {
        words.join(" ")
    };
    Checkbox {
        line,
        id,
        status,
        title,
        priority,
        due,
        tags,
    }
}

/// `[[Note|alias]]` → `alias`, `[[Note]]` → `Note`, `[text](url)` → `text`.
fn unlink(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut rest = text;
    while let Some(start) = rest.find('[') {
        out.push_str(&rest[..start]);
        let tail = &rest[start..];
        if let Some(inner) = tail.strip_prefix("[[")
            && let Some(end) = inner.find("]]")
        {
            let link = &inner[..end];
            out.push_str(link.rsplit_once('|').map_or(link, |(_, alias)| alias));
            rest = &inner[end + 2..];
        } else if let Some(end) = tail.find("](")
            && let Some(close) = tail[end..].find(')')
        {
            out.push_str(&tail[1..end]);
            rest = &tail[end + close + 1..];
        } else {
            out.push('[');
            rest = &tail[1..];
        }
    }
    out.push_str(rest);
    out
}

fn is_date(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() == 10
        && b[4] == b'-'
        && b[7] == b'-'
        && b.iter()
            .enumerate()
            .all(|(i, c)| i == 4 || i == 7 || c.is_ascii_digit())
}

#[cfg(test)]
mod tests {
    use super::*;

    const NOTE: &str = "# Sprint\n\
- [ ] Call [[People/Ana|Ana]] about #pricing ⏫ 📅 2026-11-02\n\
  * [x] Ship the [banner](https://x.y) ✅ 2026-10-01\n\
1. [/] Review copy #work\n\
- [-] Dropped idea 🔽 #someday\n\
- [ ]\n\
- [ ] Same\n\
- [ ] Same\n\
```\n\
- [ ] not a task, it's code\n\
```\n\
- not a checkbox [ ]\n\
-[ ] neither\n";

    #[test]
    fn parses_checkboxes_with_metadata() {
        let boxes = parse_checkboxes(NOTE);
        let summary: Vec<_> = boxes
            .iter()
            .map(|b| (b.line, b.status, b.title.as_str()))
            .collect();
        assert_eq!(
            summary,
            [
                (1, TaskStatus::Todo, "Call Ana about"),
                (2, TaskStatus::Done, "Ship the banner"),
                (3, TaskStatus::Doing, "Review copy"),
                (4, TaskStatus::Done, "Dropped idea"),
                (6, TaskStatus::Todo, "Same"),
                (7, TaskStatus::Todo, "Same"),
            ]
        );
        assert_eq!(boxes[0].priority, Priority::High);
        assert_eq!(boxes[0].due.as_deref(), Some("2026-11-02"));
        assert_eq!(boxes[0].tags, ["pricing"]);
        assert_eq!(boxes[2].tags, ["work"]);
        assert_eq!(boxes[3].tags, ["someday"], "after the metadata too");
        assert_ne!(boxes[4].id, boxes[5].id, "repeated lines get distinct ids");
    }

    #[test]
    fn ids_ignore_metadata() {
        let open = parse_checkboxes("- [ ] Ship it 📅 2026-11-02\n");
        let done = parse_checkboxes("- [x] Ship it 📅 2026-11-03 ✅ 2026-10-28\n");
        assert_eq!(open[0].id, done[0].id);
    }

    #[test]
    fn writes_after_code_blocks_land_on_the_right_line() {
        let text = "```\n- [ ] code\n```\n- [ ] Real\n";
        let id = &parse_checkboxes(text)[0].id;
        assert_eq!(
            set_checkbox(text, id, TaskStatus::Done).unwrap(),
            "```\n- [ ] code\n```\n- [x] Real\n"
        );
    }

    #[test]
    fn ids_survive_lines_moving() {
        let before = parse_checkboxes("- [ ] A\n- [ ] B\n");
        let after = parse_checkboxes("intro\n\n- [ ] B\n- [x] A\n");
        assert_eq!(before[0].id, after[1].id);
        assert_eq!(before[1].id, after[0].id);
    }

    #[test]
    fn sets_only_the_mark_of_the_right_checkbox() {
        let boxes = parse_checkboxes(NOTE);
        let review = &boxes[2];
        let done = set_checkbox(NOTE, &review.id, TaskStatus::Done).unwrap();
        assert!(done.contains("1. [x] Review copy #work\n"));
        assert_eq!(done.len(), NOTE.len());
        let second_same = &boxes[5];
        let doing = set_checkbox(NOTE, &second_same.id, TaskStatus::Doing).unwrap();
        assert!(doing.contains("- [ ] Same\n- [/] Same\n"));
        assert_eq!(
            set_checkbox(NOTE, &review.id, TaskStatus::Doing).unwrap(),
            NOTE
        );
        assert_eq!(set_checkbox(NOTE, "missing", TaskStatus::Done), None);
    }

    #[test]
    fn reads_the_section_around_a_line() {
        let note = "# Weekly\nintro\n## Semana 44\n- [x] Mandar resumen\n- [ ] Revisar costos\n\n### Detalle\nmás\n## Semana 45\n- [ ] Otra\n";
        assert_eq!(
            section_around(note, 4),
            "## Semana 44\n- [x] Mandar resumen\n- [ ] Revisar costos\n\n### Detalle\nmás"
        );
        assert_eq!(section_around(note, 9), "## Semana 45\n- [ ] Otra");
        assert_eq!(
            section_around("- [ ] a\r\n- [ ] b\r\n", 1),
            "- [ ] a\n- [ ] b"
        );
        let fenced = "## A\n```\n# not a heading\n```\n- [ ] t\n";
        assert_eq!(section_around(fenced, 4), fenced.trim_end());
        assert_eq!(section_around("x", 3), "");
        let long: String = (0..200).map(|n| format!("line {n}\n")).collect();
        let cut = section_around(&long, 100);
        assert!(
            cut.starts_with("line 60\n") && cut.ends_with("line 140"),
            "{cut}"
        );
    }

    #[test]
    fn keeps_windows_line_endings() {
        let text = "- [ ] A\r\n- [ ] B\r\n";
        let b = &parse_checkboxes(text)[1];
        assert_eq!(b.title, "B");
        assert_eq!(
            set_checkbox(text, &b.id, TaskStatus::Done).unwrap(),
            "- [ ] A\r\n- [x] B\r\n"
        );
    }
}
