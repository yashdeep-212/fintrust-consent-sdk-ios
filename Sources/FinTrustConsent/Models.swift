import Foundation

/// A single cookie/tracer entry as returned by GET /api/cookies/organization/{organizationId}
public struct ConsentCookie {
    public let cookieCategoryId: String?
    public let categoryName: String

    static func fromJson(_ obj: [String: Any]) -> ConsentCookie {
        let categoryId = (obj["cookieCategoryId"] as? String) ?? (obj["CookieCategoryId"] as? String)
        let categoryName = (obj["categoryName"] as? String) ?? (obj["CategoryName"] as? String) ?? "Other"
        return ConsentCookie(cookieCategoryId: categoryId, categoryName: categoryName)
    }
}

/// A grouped category, e.g. { name: "Analytics", isNecessary: false, count: 4 }
public struct ConsentCategory {
    public let name: String
    public let isNecessary: Bool
    public let count: Int
}

public enum ConsentStatus: String {
    case accepted = "ACCEPTED"
    case rejected = "REJECTED"
    case partial = "PARTIAL"
}

public enum ConsentSaveMode {
    case acceptAll
    case rejectAll
    case custom
}

public struct ConsentResult {
    public let consentId: String
    public let preferences: [String: Bool]
    public let status: ConsentStatus
}

/// Equivalent of Categories.kt — pure logic, no I/O.
internal enum ConsentCategoryLogic {
    private static let necessaryNames = ["necessary", "essential", "strictly necessary"]

    static func isNecessaryCategory(_ name: String) -> Bool {
        let lower = name.lowercased()
        return necessaryNames.contains { lower.contains($0) }
    }

    static func groupCookiesByCategory(_ cookies: [ConsentCookie]) -> [ConsentCategory] {
        var order: [String: Int] = [:]
        var orderedNames: [String] = []
        for c in cookies {
            if order[c.categoryName] == nil {
                orderedNames.append(c.categoryName)
            }
            order[c.categoryName, default: 0] += 1
        }
        return orderedNames.map { name in
            ConsentCategory(name: name, isNecessary: isNecessaryCategory(name), count: order[name] ?? 0)
        }
    }

    static func buildFinalPreferences(
        categories: [ConsentCategory],
        mode: ConsentSaveMode,
        toggled: [String: Bool]
    ) -> [String: Bool] {
        var result: [String: Bool] = [:]
        for cat in categories {
            if cat.isNecessary {
                result[cat.name] = true
            } else {
                switch mode {
                case .acceptAll: result[cat.name] = true
                case .rejectAll: result[cat.name] = false
                case .custom: result[cat.name] = toggled[cat.name] ?? false
                }
            }
        }
        return result
    }

    static func computeStatus(categories: [ConsentCategory], finalPrefs: [String: Bool]) -> ConsentStatus {
        let nonNecessary = categories.filter { !$0.isNecessary }
        if nonNecessary.isEmpty { return .accepted }

        let acceptedCount = nonNecessary.filter { finalPrefs[$0.name] == true }.count
        if acceptedCount == nonNecessary.count { return .accepted }
        if acceptedCount == 0 { return .rejected }
        return .partial
    }
}
