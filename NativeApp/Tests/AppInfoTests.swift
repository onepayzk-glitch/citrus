import Foundation

@main struct AppInfoTests {
    @MainActor static func main() async throws {
        let diagnostics = FeedbackReport.diagnostics()
        precondition(diagnostics.contains("Citrus"))
        precondition(diagnostics.contains("macOS"))
        precondition(diagnostics.contains("LibreOffice:"))
        precondition(diagnostics.contains("FFmpeg:"))
        precondition(diagnostics.contains("Pages:"))

        // Privacy: diagnostics must not contain paths, file names or the feedback email.
        precondition(!diagnostics.contains("/Users/"))
        precondition(!diagnostics.contains(".app/"))
        precondition(!diagnostics.contains(AppAuthor.emailAddress))
        precondition(diagnostics.count < 2000)

        // Limited public identity.
        precondition(AppAuthor.name == "假宝玉")
        precondition(AppAuthor.githubURL?.host == "github.com")
        precondition(AppAuthor.githubURL?.path.contains(AppAuthor.githubUsername) == true)
        precondition(AppAuthor.emailAddress.contains("@"))

        // Feedback mailto is built at runtime.
        precondition(AppAuthor.mailtoURL()?.scheme == "mailto")
        precondition(AppAuthor.mailtoURL()?.absoluteString.contains("subject=") == true)

        print("PASS author identity, feedback mailto and diagnostics privacy")
    }
}
