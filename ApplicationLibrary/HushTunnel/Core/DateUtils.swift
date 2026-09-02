import Foundation

public enum DateUtils {
    private static func parseDate(_ dateInput: Any) -> Date? {
        if let d = dateInput as? Date {
            return d
        }
        guard let s = dateInput as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = iso.date(from: s) { return parsed }
        iso.formatOptions = [.withInternetDateTime]
        if let parsed = iso.date(from: s) { return parsed }
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd"
        return simple.date(from: s)
    }

    /// Returns just the Shamsi (Persian solar Hijri) calendar string, or nil if `lang` isn't Persian
    /// or the input couldn't be parsed as a date.
    public static func formatShamsiOnly(_ dateInput: Any, lang: String? = nil) -> String? {
        let effectiveLang = lang ?? UserDefaults.standard.string(forKey: "app_language") ?? "en"
        guard effectiveLang == "fa" || effectiveLang.starts(with: "fa") else { return nil }
        guard let validDate = parseDate(dateInput) else { return nil }

        let shamsiFormatter = DateFormatter()
        shamsiFormatter.calendar = Calendar(identifier: .persian)
        shamsiFormatter.locale = Locale(identifier: "fa_IR")
        shamsiFormatter.dateFormat = "d MMMM yyyy"
        return shamsiFormatter.string(from: validDate)
    }

    public static func formatDateWithShamsi(_ dateInput: Any, lang: String? = nil) -> String {
        guard let validDate = parseDate(dateInput) else {
            if let s = dateInput as? String { return s }
            return ""
        }

        let gregFormatter = DateFormatter()
        gregFormatter.dateFormat = "yyyy-MM-dd"
        gregFormatter.locale = Locale(identifier: "en_US")
        let gregStr = gregFormatter.string(from: validDate)

        if let shamsiStr = formatShamsiOnly(validDate, lang: lang) {
            return "\(gregStr) (\(shamsiStr))"
        }

        return gregStr
    }
}
