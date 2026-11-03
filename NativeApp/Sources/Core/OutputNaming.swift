import Foundation

/// Builds output file names from the user's template. Placeholders:
/// `{name}` original name, `{tool}` tool suffix, `{date}` ISO date, `{index}` batch index.
enum OutputNaming {
    static let defaultTemplate = "{name} {tool}"

    static func fileName(base: String,
                         suffix: String,
                         ext: String,
                         template: String = AppSettings.shared.outputNameTemplate,
                         date: Date = Date(),
                         index: Int? = nil) -> String {
        var pattern = template.trimmingCharacters(in: .whitespacesAndNewlines)
        if pattern.isEmpty { pattern = defaultTemplate }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var name = pattern
            .replacingOccurrences(of: "{name}", with: base)
            .replacingOccurrences(of: "{tool}", with: suffix)
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: date))
        if let index {
            name = name.replacingOccurrences(of: "{index}", with: String(index))
        } else {
            name = name.replacingOccurrences(of: "{index}", with: "")
        }
        // Keep the result a single path component and tidy separators.
        name = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        while name.contains("  ") { name = name.replacingOccurrences(of: "  ", with: " ") }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " .-_"))
        if name.isEmpty { name = "\(base) \(suffix)".trimmingCharacters(in: .whitespaces) }
        if name.isEmpty { name = "output" }
        return "\(name).\(ext)"
    }
}
