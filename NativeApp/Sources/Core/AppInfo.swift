import AppKit
import Foundation

/// Public author identity. Only limited information is shown to users:
/// a name, a GitHub profile and a feedback email that is never rendered as plain text
/// in the UI. The email is assembled at runtime for mailto/copy actions only.
enum AppAuthor {
    static let name = "假宝玉"
    static let githubUsername = "onepayzk-glitch"

    private static let emailLocalPart = "iqzugjhot"
    private static let emailDomain = "163.com"

    static var emailAddress: String { emailLocalPart + "@" + emailDomain }

    static var githubURL: URL? {
        URL(string: "https://github.com/" + githubUsername)
    }

    static func mailtoURL(subject: String = "Open Tangerine 反馈") -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = emailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: FeedbackReport.diagnostics()),
        ]
        return components.url
    }
}

/// Diagnostics that are safe to paste into a bug report: version and environment only.
/// File names, paths, account data and the email address are never included.
enum FeedbackReport {
    static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }

    static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    static func diagnostics() -> String {
        var lines: [String] = []
        lines.append("Open Tangerine \(appVersion)")
        lines.append("macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · \(architecture)")
        lines.append("Language: \(AppLanguage.resolved.rawValue)")
        lines.append("LibreOffice: \(ExternalDependency.libreOffice.isInstalled ? "installed" : "missing")")
        lines.append("FFmpeg: \(ExternalDependency.ffmpeg.isInstalled ? "installed" : "missing")")
        lines.append("Pages: \(ExternalDependency.pages.isInstalled ? "installed" : "missing")")
        lines.append("UI language: \(L10n.isChinese ? "zh-Hans" : "en")")
        return lines.joined(separator: "\n")
    }

    static func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics(), forType: .string)
    }
}
