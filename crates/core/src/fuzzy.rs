/// Damerau-Levenshtein distance between two strings (see @damlev).
pub fn levenshtein(a: &str, b: &str) -> usize {
    strsim::damerau_levenshtein(a, b)
}

/// Find the best fuzzy match for `input` among `candidates`.
/// Uses Damerau-Levenshtein distance (@damlev) with ~67% similarity threshold.
/// Returns the closest candidate(s) above threshold, up to 3.
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

    scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

    let threshold = 0.67;

    let best_score = scored.first().map(|s| s.1).unwrap_or(0.0);
    if best_score < threshold { return vec![]; }

    scored.into_iter()
        .filter(|(_, score)| *score >= best_score - 0.01)
        .take(3)
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
    fn test_transposition() {
        // Damerau-Levenshtein handles transpositions
        assert_eq!(levenshtein("levenshtein", "levensthein"), 1);
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
