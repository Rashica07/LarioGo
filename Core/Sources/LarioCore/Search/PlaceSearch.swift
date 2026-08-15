import Foundation

/// Pure filtering, ranking and sorting over a set of places.
///
/// Stateless and deterministic on purpose: every input, including "now", is
/// passed in. That is what makes the discovery behaviour testable without a
/// simulator, a clock, or a network.
public enum PlaceSearch {

    // MARK: - Entry point

    /// Applies `query` to `places` and returns ordered results.
    public static func run(
        query: PlaceQuery,
        over places: [Place],
        now: Date = Date()
    ) -> [PlaceResult] {
        let terms = tokenize(query.text)

        let matched: [(place: Place, score: Double)] = places.compactMap { place in
            guard matches(place, query: query, terms: terms, now: now) else { return nil }
            return (place, relevanceScore(for: place, terms: terms))
        }

        let results = matched.map { entry in
            PlaceResult(
                place: entry.place,
                distance: query.origin.map { entry.place.coordinate.distance(to: $0) }
            )
        }

        return sort(results, by: query.sort, scores: Dictionary(
            matched.map { ($0.place.id, $0.score) },
            uniquingKeysWith: { first, _ in first }
        ))
    }

    // MARK: - Filtering

    static func matches(
        _ place: Place,
        query: PlaceQuery,
        terms: [String],
        now: Date
    ) -> Bool {
        if !query.kinds.isEmpty && !query.kinds.contains(place.kind) { return false }
        if !query.categories.isEmpty && !query.categories.contains(place.category) { return false }
        if query.featuredOnly && !place.isFeatured { return false }

        if let minimumRating = query.minimumRating {
            // An unrated place cannot satisfy a rating floor. Treating nil as
            // passing would surface brand-new listings above rated ones.
            guard let rating = place.rating, rating >= minimumRating else { return false }
        }

        if let maximumPrice = query.maximumPriceLevel {
            // Unknown price is not excluded: most attractions have no price
            // level, and hiding them from a "cheap eats" filter that the user
            // applied globally would be surprising.
            if let price = place.priceLevel, price > maximumPrice { return false }
        }

        if !query.cuisines.isEmpty {
            let placeCuisines = Set((place.dining?.cuisines ?? []).map(normalize))
            guard !placeCuisines.isDisjoint(with: Set(query.cuisines.map(normalize))) else {
                return false
            }
        }

        if let origin = query.origin, let maximumDistance = query.maximumDistance {
            guard place.coordinate.distance(to: origin) <= maximumDistance else { return false }
        }

        if let range = query.dateRange {
            // Only time-bound things are date filtered. An attraction has no
            // schedule and should not vanish because the user picked a weekend.
            if let schedule = place.schedule {
                guard overlaps(schedule: schedule, range: range) else { return false }
            } else if place.kind == .event {
                return false
            }
        }

        if !terms.isEmpty {
            // Built once, not once per term: `haystack` joins and case-folds
            // every text field on the place, so calling it inside the loop
            // rebuilt that string for each word the user typed.
            let text = haystack(for: place)
            guard terms.allSatisfy({ text.contains($0) }) else { return false }
        }

        return true
    }

    static func overlaps(schedule: EventSchedule, range: ClosedRange<Date>) -> Bool {
        let start = schedule.startDate
        let end = schedule.endDate ?? schedule.startDate
        return start <= range.upperBound && end >= range.lowerBound
    }

    // MARK: - Relevance

    /// Weighted match score. Higher is better.
    ///
    /// Name matches dominate, because someone typing "Piona" wants the abbey,
    /// not every description that mentions it. A prefix match on the name beats
    /// a mid-word one so short queries feel like autocomplete.
    static func relevanceScore(for place: Place, terms: [String]) -> Double {
        guard !terms.isEmpty else {
            // With no text, rank by quality so "browse all" is not arbitrary.
            return (place.rating ?? 0) + (place.isFeatured ? 1 : 0)
        }

        let name = normalize(place.name)
        let tagline = normalize(place.tagline)
        let summary = normalize(place.summary)
        let tags = place.tags.map(normalize)
        let cuisines = (place.dining?.cuisines ?? []).map(normalize)

        var score = 0.0
        for term in terms {
            if name == term {
                score += 100
            } else if name.hasPrefix(term) {
                score += 60
            } else if name.contains(term) {
                score += 40
            }
            if tags.contains(where: { $0 == term }) { score += 25 }
            if cuisines.contains(where: { $0.contains(term) }) { score += 20 }
            if tagline.contains(term) { score += 10 }
            if summary.contains(term) { score += 5 }
        }

        // Small tie-breakers so equally-matching places order sensibly.
        score += (place.rating ?? 0)
        if place.isFeatured { score += 1 }
        return score
    }

    // MARK: - Sorting

    static func sort(
        _ results: [PlaceResult],
        by sort: PlaceSort,
        scores: [UUID: Double]
    ) -> [PlaceResult] {
        switch sort {
        case .relevance:
            return results.sorted {
                let left = scores[$0.place.id] ?? 0
                let right = scores[$1.place.id] ?? 0
                if left != right { return left > right }
                return $0.place.name.localizedCaseInsensitiveCompare($1.place.name) == .orderedAscending
            }

        case .distance:
            // Places with no known distance sink to the bottom rather than
            // sorting as if they were at zero metres.
            return results.sorted {
                switch ($0.distance, $1.distance) {
                case let (left?, right?):
                    if left != right { return left < right }
                    return $0.place.name.localizedCaseInsensitiveCompare($1.place.name) == .orderedAscending
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil):
                    return $0.place.name.localizedCaseInsensitiveCompare($1.place.name) == .orderedAscending
                }
            }

        case .rating:
            return results.sorted {
                let left = $0.place.rating ?? -1
                let right = $1.place.rating ?? -1
                if left != right { return left > right }
                // More reviews is a stronger signal at equal rating.
                if $0.place.reviewCount != $1.place.reviewCount {
                    return $0.place.reviewCount > $1.place.reviewCount
                }
                return $0.place.name.localizedCaseInsensitiveCompare($1.place.name) == .orderedAscending
            }

        case .priceLowToHigh:
            return results.sorted {
                let left = $0.place.priceLevel?.rawValue ?? Int.max
                let right = $1.place.priceLevel?.rawValue ?? Int.max
                if left != right { return left < right }
                return $0.place.name.localizedCaseInsensitiveCompare($1.place.name) == .orderedAscending
            }

        case .name:
            return results.sorted {
                $0.place.name.localizedCaseInsensitiveCompare($1.place.name) == .orderedAscending
            }
        }
    }

    // MARK: - Text helpers

    /// Lowercased, diacritic-stripped form so "Nicolò" matches "nicolo".
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    static func tokenize(_ text: String) -> [String] {
        normalize(text)
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    static func haystack(for place: Place) -> String {
        var parts = [place.name, place.tagline, place.summary, place.about, place.region]
        parts.append(contentsOf: place.tags)
        parts.append(contentsOf: place.dining?.cuisines ?? [])
        if let address = place.address { parts.append(address) }
        return normalize(parts.joined(separator: " "))
    }
}
