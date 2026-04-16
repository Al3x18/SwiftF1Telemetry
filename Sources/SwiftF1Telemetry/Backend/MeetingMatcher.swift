import Foundation

struct MeetingMatcher {
    // MARK: - Match Score
    private enum MatchScore: Comparable {
        case noMatch
        case substringFieldMatch
        case tokenPrefixMatch(tokenCount: Int)
        case exactTokenMatch(tokenCount: Int)
        case exactFieldMatch

        private var rank: Int {
            switch self {
            case .noMatch:
                return 0
            case .substringFieldMatch:
                return 1
            case .tokenPrefixMatch:
                return 2
            case .exactTokenMatch:
                return 3
            case .exactFieldMatch:
                return 4
            }
        }

        private var specificity: Int {
            switch self {
            case .tokenPrefixMatch(let tokenCount), .exactTokenMatch(let tokenCount):
                return tokenCount
            default:
                return 0
            }
        }

        static func < (lhs: MatchScore, rhs: MatchScore) -> Bool {
            if lhs.rank != rhs.rank {
                return lhs.rank < rhs.rank
            }
            return lhs.specificity < rhs.specificity
        }
    }

    func bestMatch(for query: String, in meetings: [RawMeeting]) -> RawMeeting? {
        var bestMatch: (meeting: RawMeeting, score: MatchScore)?

        for meeting in meetings {
            let score = matchScore(for: query, in: meeting)
            guard score != .noMatch else { continue }

            if let currentBest = bestMatch, currentBest.score >= score {
                continue
            }

            bestMatch = (meeting, score)
        }

        return bestMatch?.meeting
    }

    private func matchScore(for query: String, in meeting: RawMeeting) -> MatchScore {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return .noMatch }

        let queryTokens = tokens(from: query)
        let searchFields = searchableFields(for: meeting)
        let normalizedFields = searchFields.map(normalize)

        if normalizedFields.contains(normalizedQuery) {
            return .exactFieldMatch
        }

        let candidateTokens = searchFields.flatMap(tokens)
        guard !queryTokens.isEmpty else { return .noMatch }

        if queryTokens.allSatisfy(candidateTokens.contains) {
            return .exactTokenMatch(tokenCount: queryTokens.count)
        }

        if queryTokens.allSatisfy({ queryToken in
            guard queryToken.count > 3 else {
                return false
            }
            return candidateTokens.contains(where: { candidateToken in
                candidateToken.hasPrefix(queryToken)
            })
        }) {
            return .tokenPrefixMatch(tokenCount: queryTokens.count)
        }

        // Avoid overly broad substring matching (e.g. "spa" matching "españa")
        // by only applying contains checks for longer queries.
        if normalizedQuery.count >= 4,
           normalizedFields.contains(where: { $0.contains(normalizedQuery) }) {
            return .substringFieldMatch
        }

        return .noMatch
    }

    private func searchableFields(for meeting: RawMeeting) -> [String] {
        [
            meeting.name,
            meeting.officialName,
            meeting.location,
            meeting.circuit.shortName,
        ]
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func tokens(from value: String) -> [String] {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}