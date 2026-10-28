//! Timestamps as the APIs send them (RFC 3339 and Jira's `+0000` variant).

use kumo_domain::time::Timestamp;

/// `2026-10-28T14:03:11.123Z`, `…+02:00` or `…+0200`.
pub(crate) fn parse_timestamp(raw: &str) -> Option<Timestamp> {
    let b = raw.trim().as_bytes();
    if b.len() < 19 || b[4] != b'-' || b[7] != b'-' || !matches!(b[10], b'T' | b' ') {
        return None;
    }
    let num = |from: usize, len: usize| -> Option<i64> {
        std::str::from_utf8(b.get(from..from + len)?)
            .ok()?
            .parse()
            .ok()
    };
    let (year, month, day) = (num(0, 4)?, num(5, 2)?, num(8, 2)?);
    let (hour, minute, second) = (num(11, 2)?, num(14, 2)?, num(17, 2)?);
    let mut at = 19;
    let mut nanos = 0_i64;
    if b.get(at) == Some(&b'.') {
        at += 1;
        let digits = b[at..].iter().take_while(|c| c.is_ascii_digit()).count();
        let fraction = num(at, digits.min(9))?;
        nanos = fraction * 10_i64.pow(9 - u32::try_from(digits.min(9)).ok()?);
        at += digits;
    }
    let offset = match b.get(at) {
        None | Some(b'Z' | b'z') => 0,
        Some(sign @ (b'+' | b'-')) => {
            let hours = num(at + 1, 2)?;
            let minutes = if b.get(at + 3) == Some(&b':') {
                num(at + 4, 2)?
            } else {
                num(at + 3, 2)?
            };
            let seconds = (hours * 60 + minutes) * 60;
            if *sign == b'+' { seconds } else { -seconds }
        }
        _ => return None,
    };
    if !(1..=12).contains(&month)
        || !(1..=31).contains(&day)
        || hour > 23
        || minute > 59
        || second > 60
    {
        return None;
    }
    let seconds =
        days_from_civil(year, month, day) * 86_400 + hour * 3600 + minute * 60 + second - offset;
    let total = i128::from(seconds) * 1_000_000_000 + i128::from(nanos);
    u64::try_from(total).ok().map(Timestamp::from_unix_nanos)
}

/// Days since 1970-01-01 (Howard Hinnant's algorithm).
fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = year.div_euclid(400);
    let yoe = year - era * 400;
    let doy = (153 * (month + if month > 2 { -3 } else { 9 }) + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

/// `YYYY-MM-DD` from a date or date-time.
pub(super) fn date_part(raw: &str) -> Option<String> {
    let date = raw.trim().get(..10)?;
    let b = date.as_bytes();
    (b[4] == b'-' && b[7] == b'-' && date.chars().filter(char::is_ascii_digit).count() == 8)
        .then(|| date.to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn secs(raw: &str) -> Option<u64> {
        parse_timestamp(raw).map(|t| t.as_unix_nanos() / 1_000_000_000)
    }

    #[test]
    fn parses_the_formats_apis_send() {
        assert_eq!(secs("1970-01-01T00:00:00Z"), Some(0));
        assert_eq!(secs("2026-10-28T14:03:11Z"), Some(1_793_196_191));
        assert_eq!(secs("2026-10-28T16:03:11+02:00"), Some(1_793_196_191));
        assert_eq!(secs("2026-10-28T11:03:11.000-0300"), Some(1_793_196_191));
        assert_eq!(
            parse_timestamp("2026-10-28T14:03:11.123456Z")
                .unwrap()
                .as_unix_nanos()
                % 1_000_000_000,
            123_456_000
        );
        assert_eq!(secs("2024-02-29T00:00:00Z"), Some(1_709_164_800));
        assert_eq!(secs("not a date"), None);
        assert_eq!(secs("2026-13-01T00:00:00Z"), None);
    }

    #[test]
    fn takes_the_date_part() {
        assert_eq!(
            date_part("2026-11-02T10:00:00Z").as_deref(),
            Some("2026-11-02")
        );
        assert_eq!(date_part("2026-11-02").as_deref(), Some("2026-11-02"));
        assert_eq!(date_part("tomorrow"), None);
    }
}
