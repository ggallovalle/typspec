/// Levenshtein edit distance between two strings.
pub fn levenshtein(a: &str, b: &str) -> usize {
    let a_len = a.len();
    let b_len = b.len();

    if a_len == 0 { return b_len; }
    if b_len == 0 { return a_len; }

    let a_bytes = a.as_bytes();
    let b_bytes = b.as_bytes();

    // Use two rows to save memory
    let mut prev: Vec<usize> = (0..=b_len).collect();
    let mut curr: Vec<usize> = vec![0; b_len + 1];

    for i in 1..=a_len {
        curr[0] = i;
        for j in 1..=b_len {
            let cost = if a_bytes[i - 1] == b_bytes[j - 1] { 0 } else { 1 };
            curr[j] = min3(
                prev[j] + 1,          // deletion
                curr[j - 1] + 1,      // insertion
                prev[j - 1] + cost,   // substitution
            );
        }
        std::mem::swap(&mut prev, &mut curr);
    }

    prev[b_len]
}

fn min3(a: usize, b: usize, c: usize) -> usize {
    a.min(b).min(c)
}

/// Find the best fuzzy match for `input` among `candidates`.
/// Returns the closest candidate and its similarity score (0.0–1.0).
/// Only returns a match if similarity exceeds the threshold (~67%).
pub fn best_fuzzy_match<'a>(input: &str, candidates: &'a [String]) -> Vec<&'a String> {
    if candidates.is_empty() { return vec![]; }

    let input = input.to_lowercase();

    let mut scored: Vec<(&String, f64)> = candidates
        .iter()
        .map(|candidate| {
            let candidate_lower = candidate.to_lowercase();
            let dist = levenshtein(&input, &candidate_lower);
            let max_len = input.len().max(candidate_lower.len());
            let similarity = if max_len == 0 { 1.0 } else { 1.0 - (dist as f64 / max_len as f64) };
            (candidate, similarity)
        })
        .collect();

    // Sort by similarity descending
    scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    // Threshold: ~67% similarity (matching clap's heuristic)
    let threshold = 0.67;

    // Filter to best matches above threshold
    let best_score = scored.first().map(|s| s.1).unwrap_or(0.0);
    if best_score < threshold { return vec![]; }

    scored.into_iter()
        .filter(|(_, score)| *score >= best_score - 0.01) // within 1% of best
        .take(3) // at most 3 suggestions
        .map(|(name, _)| name)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_levenshtein_identical() {
        assert_eq!(levenshtein("hello", "hello"), 0);
    }

    #[test]
    fn test_levenshtein_completely_different() {
        assert_eq!(levenshtein("abc", "xyz"), 3);
    }

    #[test]
    fn test_levenshtein_one_insertion() {
        assert_eq!(levenshtein("cat", "cats"), 1);
    }

    #[test]
    fn test_fuzzy_obvious_typo() {
        let candidates = vec!["customizable-paths".to_string(), "module-api".to_string()];
        let result = best_fuzzy_match("customizalbs-path", &candidates);
        assert!(result.contains(&&"customizable-paths".to_string()));
    }

    #[test]
    fn test_fuzzy_no_match() {
        let candidates = vec!["module-api".to_string(), "cli".to_string()];
        let result = best_fuzzy_match("completely-unrelated", &candidates);
        assert!(result.is_empty());
    }

    #[test]
    fn test_exact_match_returns_candidate() {
        let candidates = vec!["module-api".to_string()];
        let result = best_fuzzy_match("module-api", &candidates);
        assert!(result.contains(&&"module-api".to_string()));
    }
}
