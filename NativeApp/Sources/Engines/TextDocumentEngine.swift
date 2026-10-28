import AppKit
import Foundation
import PDFKit

/// Shared shape for text-like document extraction used by conversions.
struct ExtractedDocument {
    var title: String = ""
    var lines: [String] = []
    var table: [[String]] = []

    var text: String { lines.joined(separator: "\n") }
}

/// Converts every text-like office format that the native engines do not already handle:
/// DOCX, PAGES, MD, RTF, RTFD, text clippings, EPUB, TXT, CSV, TSV, XLSX, ODS, PPT/PPTX and PDF text.
struct TextDocumentEngine: ConversionEngine {
    static let readable: Set<FileFormat> = [
        .txt, .md, .html, .rtf, .rtfd, .textClipping, .docx, .pages, .epub,
        .csv, .tsv, .xlsx, .xls, .ods, .ppt, .pptx, .pdf,
    ]
    static let writable: Set<FileFormat> = [
        .txt, .md, .html, .docx, .epub, .pdf, .png, .jpg, .csv, .tsv, .xlsx, .ods, .srt, .vtt,
    ]

    func supports(from: FileFormat, to: FileFormat) -> Bool {
        guard Self.readable.contains(from), Self.writable.contains(to) else { return false }
        // Existing DocumentEngine already owns these pairs; avoid duplicate claims.
        if from == .pdf, [.docx, .jpg, .png, .txt].contains(to) { return false }
        if from == .txt, [.pdf, .jpg, .png, .srt, .vtt].contains(to) { return false }
        return true
    }

    func convert(_ request: ConversionRequest) async throws {
        let document = try await TextDocumentReader.read(request.source, format: request.sourceFormat, progress: request.progress)
        try await TextDocumentWriter.write(document, format: request.target, to: request.destination, progress: request.progress)
        request.progress(1)
    }
}

enum TextDocumentReader {
    static func read(_ url: URL, format: FileFormat, progress: @escaping (Double) -> Void = { _ in }) async throws -> ExtractedDocument {
        var document = ExtractedDocument(title: url.deletingPathExtension().lastPathComponent)
        switch format {
        case .txt, .md:
            document.lines = try TextFile.read(url).components(separatedBy: .newlines)
        case .html:
            document = .init(title: document.title, lines: Reader.htmlLines(try TextFile.read(url)), table: [])
        case .rtf:
            document.lines = Reader.rtfLines(try TextFile.read(url))
        case .rtfd:
            let candidates = ["TXT.rtf", "TXT.rtfd/TXT.rtf"]
            var found = false
            for candidate in candidates {
                let inner = url.appendingPathComponent(candidate)
                if let text = try? String(contentsOf: inner, encoding: .utf8) {
                    document.lines = Reader.rtfLines(text); found = true; break
                }
            }
            if !found { throw OpenTangerineError.invalidInput("This RTFD package has no readable TXT.rtf inside.") }
        case .textClipping:
            document.lines = Reader.printableLines(try TextFile.read(url))
        case .csv:
            document = .init(title: document.title, lines: [], table: Reader.delimitedTable(try TextFile.read(url), delimiter: ","))
        case .tsv:
            document = .init(title: document.title, lines: [], table: Reader.delimitedTable(try TextFile.read(url), delimiter: "\t"))
        case .docx:
            document = try await OfficeArchive.docx(url)
        case .pages:
            document = try await OfficeArchive.pages(url)
        case .epub:
            document = try await OfficeArchive.epub(url)
        case .xlsx:
            document = try await OfficeArchive.xlsx(url)
        case .xls:
            document = try OfficeArchive.legacySpreadsheetText(url)
        case .ods:
            document = try await OfficeArchive.ods(url)
        case .pptx:
            document = try await OfficeArchive.pptx(url)
        case .ppt:
            document = try OfficeArchive.legacyPowerPointText(url)
        case .pdf:
            document = try Reader.pdf(url)
        default:
            throw OpenTangerineError.unsupportedConversion(format, .txt)
        }
        progress(0.7)
        return document
    }
}

enum TextDocumentWriter {
    static func write(_ document: ExtractedDocument, format: FileFormat, to destination: URL, progress: @escaping (Double) -> Void = { _ in }) async throws {
        let lines = document.lines.isEmpty && !document.table.isEmpty
            ? document.table.map { $0.joined(separator: "\t") }
            : document.lines
        let text = lines.joined(separator: "\n")
        switch format {
        case .txt:
            try text.write(to: destination, atomically: true, encoding: .utf8)
        case .md:
            let heading = document.title.isEmpty ? "" : "# \(document.title)\n\n"
            try (heading + text).write(to: destination, atomically: true, encoding: .utf8)
        case .html:
            try Writer.html(document, to: destination)
        case .docx:
            try await DocxWriter.write(paragraphs: lines.isEmpty ? [""] : lines, images: [], to: destination)
        case .epub:
            try await Writer.epub(document, to: destination)
        case .pdf:
            try TextRenderer.writePDF(text, to: destination)
        case .png, .jpg:
            let image = try TextRenderer.renderWholeDocument(text)
            try ImageIOBridge.write(image, to: destination, format: format, quality: 0.92)
        case .csv:
            try Writer.csv(document, delimiter: ",", to: destination)
        case .tsv:
            try Writer.csv(document, delimiter: "\t", to: destination)
        case .xlsx:
            try await Writer.xlsx(document, to: destination)
        case .ods:
            try await Writer.ods(document, to: destination)
        case .srt, .vtt:
            let cues = SubtitleParser.parse(text, hint: .txt)
            try SubtitleParser.serialize(cues, as: format).write(to: destination, atomically: true, encoding: .utf8)
        default:
            throw OpenTangerineError.invalidInput("Exporting to \(format.displayName) is not available yet. Convert to PDF, DOCX or TXT instead.")
        }
        progress(1)
    }
}

// MARK: - Readers

private enum Reader {
    static func pdf(_ url: URL) throws -> ExtractedDocument {
        let data = try Data(contentsOf: url)
        guard let document = PDFDocument(data: data) else { throw OpenTangerineError.unreadable(url) }
        var lines: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            if let content = page.string { lines += content.components(separatedBy: .newlines) }
        }
        if lines.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            throw OpenTangerineError.invalidInput("This PDF has no selectable text. Scanned pages require OCR, which is not supported yet.")
        }
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: lines, table: [])
    }

    static func htmlLines(_ html: String) -> [String] {
        var text = html
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</div>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</h[1-6]>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?s)<style[^>]*>.*?</style>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?s)<script[^>]*>.*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = unescape(text)
        return text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func rtfLines(_ rtf: String) -> [String] {
        var text = rtf
        text = text.replacingOccurrences(of: "\\\\'[0-9a-fA-F]{2}", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\\\[a-zA-Z]+-?[0-9]* ?", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "[{}]", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\\\par", with: "\n")
        return text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func printableLines(_ raw: String) -> [String] {
        raw.components(separatedBy: .newlines)
            .map { $0.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0.isWhitespace || $0.isPunctuation) } }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func delimitedTable(_ text: String, delimiter: Character) -> [[String]] {
        text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { line in
                var cells: [String] = []
                var current = ""
                var quoted = false
                for character in line {
                    if character == "\"" { quoted.toggle(); continue }
                    if character == delimiter, !quoted { cells.append(current); current = ""; continue }
                    current.append(character)
                }
                cells.append(current)
                return cells
            }
    }

    static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    static func xmlParagraphs(_ xml: String, breakTag: String) -> [String] {
        var text = xml
        text = text.replacingOccurrences(of: breakTag, with: "\n")
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = unescape(text)
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    struct XMLCell { let attributes: String; let body: String }

    static func cells(in rowXML: String) -> [XMLCell] {
        guard let expression = try? NSRegularExpression(pattern: "<c\\b([^>]*?)(?:/>|>(.*?)</c>)") else { return [] }
        let range = NSRange(rowXML.startIndex..., in: rowXML)
        return expression.matches(in: rowXML, range: range).map { match in
            let attributes = Range(match.range(at: 1), in: rowXML).map { String(rowXML[$0]) } ?? ""
            let body = match.numberOfRanges > 2 ? Range(match.range(at: 2), in: rowXML).map { String(rowXML[$0]) } ?? "" : ""
            return XMLCell(attributes: attributes, body: body)
        }
    }

    static func tags(_ pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let captured = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[captured])
        }
    }
}

// MARK: - OOXML / package readers

private enum OfficeArchive {
    static func staging(_ name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("opentangerine-doc-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func docx(_ url: URL) async throws -> ExtractedDocument {
        let staging = try staging("docx")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await ZipTool.unzip(url, into: staging)
        let xmlURL = staging.appendingPathComponent("word/document.xml")
        guard let xml = try? String(contentsOf: xmlURL, encoding: .utf8) else { throw OpenTangerineError.invalidInput("This DOCX has no readable word/document.xml.") }
        var text = xml
        text = text.replacingOccurrences(of: "<w:tab/>", with: "\t")
        text = text.replacingOccurrences(of: "</w:tc>", with: "\t")
        text = text.replacingOccurrences(of: "</w:tr>", with: "\n")
        let lines = Reader.xmlParagraphs(text, breakTag: "</w:p>")
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: lines, table: [])
    }

    static func pages(_ url: URL) async throws -> ExtractedDocument {
        let staging = try staging("pages")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await ZipTool.unzip(url, into: staging)
        let enumerator = FileManager.default.enumerator(at: staging, includingPropertiesForKeys: [.isRegularFileKey])
        var previewPDF: URL?
        while let candidate = enumerator?.nextObject() as? URL {
            let name = candidate.lastPathComponent.lowercased()
            if name.hasSuffix(".pdf") { previewPDF = candidate; break }
        }
        if let previewPDF { return try Reader.pdf(previewPDF) }
        throw OpenTangerineError.invalidInput("This Pages file has no readable preview. Open it in Pages and export to PDF or DOCX first.")
    }

    static func epub(_ url: URL) async throws -> ExtractedDocument {
        let staging = try staging("epub")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await ZipTool.unzip(url, into: staging)
        let enumerator = FileManager.default.enumerator(at: staging, includingPropertiesForKeys: nil)
        var lines: [String] = []
        while let candidate = enumerator?.nextObject() as? URL {
            let ext = candidate.pathExtension.lowercased()
            guard ["xhtml", "html", "htm"].contains(ext) else { continue }
            guard let html = try? String(contentsOf: candidate, encoding: .utf8) else { continue }
            lines += Reader.htmlLines(html)
        }
        guard !lines.isEmpty else { throw OpenTangerineError.invalidInput("This EPUB has no readable XHTML content.") }
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: lines, table: [])
    }

    static func xlsx(_ url: URL) async throws -> ExtractedDocument {
        let staging = try staging("xlsx")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await ZipTool.unzip(url, into: staging)
        var shared: [String] = []
        if let sharedXML = try? String(contentsOf: staging.appendingPathComponent("xl/sharedStrings.xml"), encoding: .utf8) {
            shared = Reader.tags("<t[^>]*>([^<]*)</t>", in: sharedXML)
        }
        let sheetURL = staging.appendingPathComponent("xl/worksheets/sheet1.xml")
        guard let sheetXML = try? String(contentsOf: sheetURL, encoding: .utf8) else { throw OpenTangerineError.invalidInput("This workbook has no readable first sheet.") }
        var rows: [[String]] = []
        for rowXML in Reader.tags("<row[^>]*>(.*?)</row>", in: sheetXML) {
            var cells: [String] = []
            for cell in Reader.cells(in: rowXML) {
                if cell.attributes.contains("t=\"s\""), let value = Reader.tags("<v>([0-9]+)</v>", in: cell.body).first, let index = Int(value), index < shared.count {
                    cells.append(shared[index])
                } else if let value = Reader.tags("<v>([^<]*)</v>", in: cell.body).first {
                    cells.append(value)
                } else if let inline = Reader.tags("<t[^>]*>([^<]*)</t>", in: cell.body).first {
                    cells.append(inline)
                } else {
                    cells.append("")
                }
            }
            if cells.contains(where: { !$0.isEmpty }) { rows.append(cells) }
        }
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: [], table: rows)
    }

    static func ods(_ url: URL) async throws -> ExtractedDocument {
        let staging = try staging("ods")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await ZipTool.unzip(url, into: staging)
        guard let xml = try? String(contentsOf: staging.appendingPathComponent("content.xml"), encoding: .utf8) else { throw OpenTangerineError.invalidInput("This ODS has no readable content.xml.") }
        var rows: [[String]] = []
        for rowXML in Reader.tags("<table:table-row[^>]*>(.*?)</table:table-row>", in: xml) {
            var cells: [String] = []
            for cell in Reader.tags("<table:table-cell[^>]*>(.*?)</table:table-cell>", in: rowXML) {
                let text = Reader.tags("<text:p[^>]*>(.*?)</text:p>", in: cell).joined(separator: " ")
                cells.append(Reader.unescape(Reader.tags("<[^>]+>", in: text).isEmpty ? text : text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)))
            }
            if cells.contains(where: { !$0.isEmpty }) { rows.append(cells) }
        }
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: [], table: rows)
    }

    static func pptx(_ url: URL) async throws -> ExtractedDocument {
        let staging = try staging("pptx")
        defer { try? FileManager.default.removeItem(at: staging) }
        try await ZipTool.unzip(url, into: staging)
        let slidesDirectory = staging.appendingPathComponent("ppt/slides")
        let files = (try? FileManager.default.contentsOfDirectory(at: slidesDirectory, includingPropertiesForKeys: nil)) ?? []
        let sorted = files.filter { $0.lastPathComponent.hasPrefix("slide") }.sorted {
            ($0.lastPathComponent.compactMap(\.wholeNumberValue).reduce(0) { $0 * 10 + $1 }) <
            ($1.lastPathComponent.compactMap(\.wholeNumberValue).reduce(0) { $0 * 10 + $1 })
        }
        guard !sorted.isEmpty else { throw OpenTangerineError.invalidInput("This presentation has no readable slides.") }
        var lines: [String] = []
        for (index, slide) in sorted.enumerated() {
            guard let xml = try? String(contentsOf: slide, encoding: .utf8) else { continue }
            lines.append("Slide \(index + 1)")
            lines += Reader.tags("<a:t>([^<]*)</a:t>", in: xml).map { Reader.unescape($0) }
            lines.append("")
        }
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: lines, table: [])
    }

    static func legacySpreadsheetText(_ url: URL) throws -> ExtractedDocument {
        let data = try Data(contentsOf: url)
        guard let raw = String(data: data, encoding: .isoLatin1) else { throw OpenTangerineError.unreadable(url) }
        let lines = Reader.printableLines(raw)
        guard !lines.isEmpty else { throw OpenTangerineError.invalidInput("This XLS workbook has no readable cells.") }
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: [], table: lines.map { $0.components(separatedBy: "\t") })
    }

    static func legacyPowerPointText(_ url: URL) throws -> ExtractedDocument {
        let data = try Data(contentsOf: url)
        guard let raw = String(data: data, encoding: .isoLatin1) else { throw OpenTangerineError.unreadable(url) }
        let lines = Reader.printableLines(raw)
        guard !lines.isEmpty else { throw OpenTangerineError.invalidInput("This PPT has no readable text runs.") }
        return ExtractedDocument(title: url.deletingPathExtension().lastPathComponent, lines: lines, table: [])
    }
}

// MARK: - Writers

private enum Writer {
    static func html(_ document: ExtractedDocument, to url: URL) throws {
        let body = document.lines.map { "<p>\(DocxWriter.escape($0))</p>" }.joined(separator: "\n")
        let html = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(DocxWriter.escape(document.title))</title></head>
        <body style="font-family: -apple-system, Helvetica, sans-serif; font-size: 15px; line-height: 1.5;">
        \(body)
        </body></html>
        """
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    static func csv(_ document: ExtractedDocument, delimiter: String, to url: URL) throws {
        let rows = document.table.isEmpty ? document.lines.map { [$0] } : document.table
        let text = rows.map { row in
            row.map { cell -> String in
                if cell.contains(delimiter) || cell.contains("\"") || cell.contains("\n") {
                    return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                }
                return cell
            }.joined(separator: delimiter)
        }.joined(separator: "\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func epub(_ document: ExtractedDocument, to url: URL) async throws {
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("opentangerine-epub-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        let fm = FileManager.default
        try fm.createDirectory(at: staging.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try fm.createDirectory(at: staging.appendingPathComponent("OEBPS"), withIntermediateDirectories: true)
        let title = document.title.isEmpty ? "Document" : document.title
        let paragraphs = document.lines.map { "<p>\(DocxWriter.escape($0))</p>" }.joined(separator: "\n")
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml"><head><meta charset="utf-8"><title>\(DocxWriter.escape(title))</title></head>
        <body>\(paragraphs)</body></html>
        """
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier id="book-id">urn:uuid:\(UUID().uuidString)</dc:identifier>
        <dc:title>\(DocxWriter.escape(title))</dc:title><dc:language>en</dc:language>
        </metadata>
        <manifest><item id="content" href="content.xhtml" media-type="application/xhtml+xml"/></manifest>
        <spine><itemref idref="content"/></spine>
        </package>
        """
        let container = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """
        try "application/epub+zip".write(to: staging.appendingPathComponent("mimetype"), atomically: true, encoding: .utf8)
        try container.write(to: staging.appendingPathComponent("META-INF/container.xml"), atomically: true, encoding: .utf8)
        try content.write(to: staging.appendingPathComponent("OEBPS/content.xhtml"), atomically: true, encoding: .utf8)
        try opf.write(to: staging.appendingPathComponent("OEBPS/content.opf"), atomically: true, encoding: .utf8)

        try? fm.removeItem(at: url)
        let quiet = try await Shell.run("/usr/bin/zip", ["-X", "-0", "-q", url.path, "mimetype"], currentDirectory: staging)
        guard quiet.succeeded else { throw OpenTangerineError.toolFailed("zip", quiet.stderr) }
        let rest = try await Shell.run("/usr/bin/zip", ["-X", "-r", "-q", url.path, "META-INF", "OEBPS"], currentDirectory: staging)
        guard rest.succeeded else { throw OpenTangerineError.toolFailed("zip", rest.stderr) }
    }

    static func xlsx(_ document: ExtractedDocument, to url: URL) async throws {
        let rows = document.table.isEmpty ? document.lines.map { [$0] } : document.table
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("opentangerine-xlsx-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        let fm = FileManager.default
        try fm.createDirectory(at: staging.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: staging.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try fm.createDirectory(at: staging.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)
        var sheet = ""
        for (rowIndex, row) in rows.enumerated() {
            sheet += "<row r=\"\(rowIndex + 1)\">"
            for (columnIndex, cell) in row.enumerated() {
                sheet += "<c r=\"\(columnName(columnIndex))\(rowIndex + 1)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(DocxWriter.escape(cell))</t></is></c>"
            }
            sheet += "</row>"
        }
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        </Types>
        """
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
        let workbook = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
        </workbook>
        """
        let workbookRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """
        let worksheet = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\(sheet)</sheetData></worksheet>
        """
        try contentTypes.write(to: staging.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try rootRels.write(to: staging.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
        try workbook.write(to: staging.appendingPathComponent("xl/workbook.xml"), atomically: true, encoding: .utf8)
        try workbookRels.write(to: staging.appendingPathComponent("xl/_rels/workbook.xml.rels"), atomically: true, encoding: .utf8)
        try worksheet.write(to: staging.appendingPathComponent("xl/worksheets/sheet1.xml"), atomically: true, encoding: .utf8)
        try await ZipTool.zipOrdered(directory: staging, entries: [
            "[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels", "xl/worksheets/sheet1.xml",
        ], to: url)
    }

    static func ods(_ document: ExtractedDocument, to url: URL) async throws {
        let rows = document.table.isEmpty ? document.lines.map { [$0] } : document.table
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("opentangerine-ods-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        let fm = FileManager.default
        try fm.createDirectory(at: staging.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        var table = ""
        for row in rows {
            table += "<table:table-row>"
            for cell in row {
                table += "<table:table-cell office:value-type=\"string\"><text:p>\(DocxWriter.escape(cell))</text:p></table:table-cell>"
            }
            table += "</table:table-row>"
        }
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" office:version="1.2">
        <office:body><office:spreadsheet><table:table table:name="Sheet1">\(table)</table:table></office:spreadsheet></office:body>
        </office:document-content>
        """
        let manifest = """
        <?xml version="1.0" encoding="UTF-8"?>
        <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
        <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>
        <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
        </manifest:manifest>
        """
        try "application/vnd.oasis.opendocument.spreadsheet".write(to: staging.appendingPathComponent("mimetype"), atomically: true, encoding: .utf8)
        try manifest.write(to: staging.appendingPathComponent("META-INF/manifest.xml"), atomically: true, encoding: .utf8)
        try content.write(to: staging.appendingPathComponent("content.xml"), atomically: true, encoding: .utf8)
        try? fm.removeItem(at: url)
        let mimetype = try await Shell.run("/usr/bin/zip", ["-X", "-0", "-q", url.path, "mimetype"], currentDirectory: staging)
        guard mimetype.succeeded else { throw OpenTangerineError.toolFailed("zip", mimetype.stderr) }
        let rest = try await Shell.run("/usr/bin/zip", ["-X", "-r", "-q", url.path, "META-INF", "content.xml"], currentDirectory: staging)
        guard rest.succeeded else { throw OpenTangerineError.toolFailed("zip", rest.stderr) }
    }

    static func columnName(_ index: Int) -> String {
        var value = index
        var name = ""
        repeat {
            let letter = Character(UnicodeScalar(65 + value % 26)!)
            name = String(letter) + name
            value = value / 26 - 1
        } while value >= 0
        return name
    }
}
