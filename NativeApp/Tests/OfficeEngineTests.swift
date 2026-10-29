import AppKit
import Foundation
import PDFKit

@main struct OfficeEngineTests {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("OpenTangerine-office-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        func convert(_ source: URL, _ from: FileFormat, _ to: FileFormat, _ name: String) async throws -> URL {
            let output = root.appendingPathComponent(name)
            try await Engines.convert(ConversionRequest(source: source, sourceFormat: from, target: to, destination: output, progress: { _ in }))
            return output
        }

        let health = await OfficeEngine.checkHealth()
        guard health.isReady else {
            print("SKIP Office engine tests: \(health.summary)")
            return
        }
        print("Office engine: \(health.summary)")

        let docx = root.appendingPathComponent("office.docx")
        try await DocxWriter.write(paragraphs: ["Office engine test", "Second paragraph"], images: [], to: docx)
        let docxPDF = try await convert(docx, .docx, .pdf, "office-docx.pdf")
        let document = try PDFOps.document(docxPDF)
        precondition(document.pageCount >= 1)
        precondition((document.page(at: 0)?.string ?? "").contains("Office engine test"))
        print("PASS DOCX -> PDF via LibreOffice (\(document.pageCount) page)")

        let png = try await convert(docx, .docx, .png, "office-docx.png")
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: png.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let pages = try fm.contentsOfDirectory(at: png, includingPropertiesForKeys: nil)
            precondition(!pages.isEmpty)
            print("PASS DOCX -> PNG pages via LibreOffice (\(pages.count) page files)")
        } else {
            precondition(try! ImageIOBridge.load(png).width > 0)
            print("PASS DOCX -> PNG via LibreOffice")
        }

        let csv = root.appendingPathComponent("table.csv")
        try "name,value\nalpha,1\nbeta,2\n".write(to: csv, atomically: true, encoding: .utf8)
        let xlsx = try await convert(csv, .csv, .xlsx, "table.xlsx")
        let xlsxPDF = try await convert(xlsx, .xlsx, .pdf, "table.pdf")
        precondition(try! PDFOps.document(xlsxPDF).pageCount >= 1)
        print("PASS XLSX -> PDF via LibreOffice")

        let slideSource = root.appendingPathComponent("source.pdf")
        try TextRenderer.writePDF("Slide content", to: slideSource)
        let pptx = try await convert(slideSource, .pdf, .pptx, "deck.pptx")
        let deckPDF = try await convert(pptx, .pptx, .pdf, "deck.pdf")
        precondition(try! PDFOps.document(deckPDF).pageCount >= 1)
        print("PASS PPTX -> PDF via LibreOffice")
    }
}
