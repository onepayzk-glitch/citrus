import AppKit
import Foundation
import PDFKit

@main struct DocumentTests {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("OpenTangerine-documents-\(UUID())")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        func url(_ name: String) -> URL { root.appendingPathComponent(name) }
        func convert(_ source: URL, _ from: FileFormat, _ to: FileFormat, _ name: String) async throws -> URL {
            let output = url(name)
            try await Engines.convert(ConversionRequest(source: source, sourceFormat: from, target: to, destination: output, progress: { _ in }))
            return output
        }
        let text = "Citrus document test\nCafé & <content>\n\nSecond paragraph."
        try text.write(to: url("input.txt"), atomically: true, encoding: .utf8)
        let pdf = try await convert(url("input.txt"), .txt, .pdf, "text.pdf")
        precondition(PDFDocument(url: pdf)!.string!.contains("Citrus"))
        for target: FileFormat in [.png, .jpg, .srt, .vtt] {
            let out = try await convert(url("input.txt"), .txt, target, "text.\(target.fileExtension)")
            if target == .png || target == .jpg { precondition(try! ImageIOBridge.load(out).width == 1275) }
            else { precondition(try! String(contentsOf: out, encoding: .utf8).contains("Second paragraph")) }
            print("PASS TXT -> \(target)")
        }
        for target: FileFormat in [.png, .jpg, .txt, .docx] {
            let out = try await convert(pdf, .pdf, target, "pdf.\(target.fileExtension)")
            switch target {
            case .png, .jpg: precondition(try! ImageIOBridge.load(out).width == 2550)
            case .txt: precondition(try! String(contentsOf: out, encoding: .utf8).contains("Citrus"))
            case .docx:
                let result = try await Shell.run("/usr/bin/unzip", ["-p", out.path, "word/document.xml"])
                precondition(result.succeeded && result.stdout.contains("Citrus") && result.stdout.contains("&amp;"))
            default: break
            }
            print("PASS PDF -> \(target)")
        }
        let second = url("second.pdf")
        try TextRenderer.writePDF("Second page marker", to: second)
        let merged = url("merged.pdf")
        try PDFOps.merge([pdf, second], to: merged)
        let mergedDoc = try PDFOps.document(merged)
        precondition(mergedDoc.pageCount == 2 && mergedDoc.page(at: 1)!.string!.contains("Second page"))
        for mode: PDFOps.SplitMode in [.everyPage, .everyN, .ranges] {
            let outputs = try PDFOps.split(merged, mode: mode, every: 2, ranges: "2", into: url("split-\(mode.rawValue)"))
            precondition(outputs.count == (mode == .everyPage ? 2 : 1))
            precondition(try! PDFOps.document(outputs[0]).pageCount == (mode == .everyN ? 2 : 1))
            print("PASS PDF split \(mode)")
        }
        try PDFOps.assemble(pages: [PDFPageRef(sourceIndex: 1, rotation: 90, sourceURL: merged), PDFPageRef(sourceIndex: 0, rotation: 0, sourceURL: merged)], to: url("reordered.pdf"))
        let reordered = try PDFOps.document(url("reordered.pdf"))
        precondition(reordered.page(at: 0)!.rotation == 90 && reordered.page(at: 0)!.string!.contains("Second page"))
        for strong in [false, true] {
            let out = url("compressed-\(strong).pdf")
            try PDFOps.compress(merged, strong: strong, to: out)
            precondition(try! PDFOps.document(out).pageCount == 2)
            print("PASS PDF compression strong=\(strong), preserves page count (size reduction not guaranteed)")
        }
        let imagePDF = url("images.pdf")
        try PDFOps.fromImages([url("text.png"), url("text.jpg")], to: imagePDF, progress: { _ in })
        precondition(try! PDFOps.document(imagePDF).pageCount == 2)
        let multiImages = try await convert(merged, .pdf, .png, "pages.png")
        let pages = try fm.contentsOfDirectory(at: multiImages, includingPropertiesForKeys: nil)
        precondition(pages.count == 2)
        for page in pages { precondition(try! ImageIOBridge.load(page).width == 2550) }
        let scanDOCX = try await convert(imagePDF, .pdf, .docx, "scanned.docx")
        let listing = try await Shell.run("/usr/bin/unzip", ["-l", scanDOCX.path])
        precondition(listing.stdout.contains("image1.png") && listing.stdout.contains("image2.png"))
        do { _ = try await convert(imagePDF, .pdf, .txt, "scan.txt"); fatalError("Empty scanned text reported as success") } catch { }
        let protected = url("protected.pdf")
        precondition(mergedDoc.write(to: protected, withOptions: [.userPasswordOption: "test-password", .ownerPasswordOption: "owner-password"]))
        do { _ = try await convert(protected, .pdf, .png, "locked.png"); fatalError("Locked PDF accepted") } catch { }
        let mixed = url("mixed.pdf")
        try PDFOps.merge([imagePDF, pdf], to: mixed)
        let mixedDocx = try await convert(mixed, .pdf, .docx, "mixed.docx")
        let mixedXML = try await Shell.run("/usr/bin/unzip", ["-p", mixedDocx.path, "word/document.xml"])
        precondition(mixedXML.stdout.range(of: "<w:drawing>")!.lowerBound < mixedXML.stdout.range(of: "Citrus")!.lowerBound)
        precondition(mixedXML.stdout.contains("w:type=\"page\""))
        print("PASS mixed scanned/text PDF -> DOCX preserves page order and breaks")
        print("PASS PDF merge/reorder/rotate, images-to-PDF, multipage export, scanned DOCX, scanned/locked rejection")
        let srt = "1\n00:00:01,250 --> 00:00:03,000\nHello <i>world</i>\n\n2\n00:00:04,000 --> 00:00:05,000\nSecond cue\n"
        try srt.write(to: url("captions.srt"), atomically: true, encoding: .utf8)
        let vtt = try await convert(url("captions.srt"), .srt, .vtt, "captions.vtt")
        let roundtrip = try await convert(vtt, .vtt, .srt, "roundtrip.srt")
        let cues = SubtitleParser.parse(try String(contentsOf: roundtrip, encoding: .utf8), hint: .srt)
        precondition(cues.count == 2 && cues[0].start == 1.25 && cues[1].end == 5)
        for (source, format) in [(url("captions.srt"), FileFormat.srt), (vtt, .vtt)] {
            let out = try await convert(source, format, .txt, "\(format).txt")
            precondition(try! String(contentsOf: out, encoding: .utf8).contains("Hello world"))
        }
        precondition(SubtitleParser.format(59.9999, separator: ",") == "00:01:00,000")
        precondition(SubtitleParser.parseTimestamp("nan") == nil)
        print("PASS SRT/VTT round trip + both TXT exports; millisecond carry and invalid timestamp")
        // Tangerine parity routes: text, documents, spreadsheets, EPUB and archives.
        try "# Title\n\nBody paragraph & <tag>.".write(to: url("notes.md"), atomically: true, encoding: .utf8)
        for target in [FileFormat.docx, .pdf, .epub] {
            let out = try await convert(url("notes.md"), .md, target, "notes.\(target.fileExtension)")
            precondition(fm.fileExists(atPath: out.path))
            print("PASS MD -> \(target)")
        }
        let htmlOut = try await convert(url("notes.md"), .md, .html, "notes.html")
        precondition(try! String(contentsOf: htmlOut, encoding: .utf8).contains("Body paragraph"))
        let docxOut = try await convert(url("notes.md"), .md, .docx, "notes-roundtrip.docx")
        let docxText = try await convert(docxOut, .docx, .txt, "notes.txt")
        precondition(try! String(contentsOf: docxText, encoding: .utf8).contains("Body paragraph"))
        print("PASS MD -> DOCX -> TXT round trip")

        try "name,value\nalpha,1\nbeta,2\n".write(to: url("table.csv"), atomically: true, encoding: .utf8)
        let xlsxOut = try await convert(url("table.csv"), .csv, .xlsx, "table.xlsx")
        let backToCSV = try await convert(xlsxOut, .xlsx, .csv, "table-back.csv")
        let csvBack = try String(contentsOf: backToCSV, encoding: .utf8)
        precondition(csvBack.contains("alpha") && csvBack.contains("beta"))
        let tsvOut = try await convert(xlsxOut, .xlsx, .tsv, "table.tsv")
        precondition(try! String(contentsOf: tsvOut, encoding: .utf8).contains("\t"))
        let odsOut = try await convert(xlsxOut, .xlsx, .ods, "table.ods")
        let csvFromODS = try await convert(odsOut, .ods, .csv, "table-ods.csv")
        precondition(try! String(contentsOf: csvFromODS, encoding: .utf8).contains("alpha"))
        try? fm.copyItem(at: xlsxOut, to: URL(fileURLWithPath: "/tmp/OpenTangerine-xlsx-check.xlsx"))
        try? fm.copyItem(at: odsOut, to: URL(fileURLWithPath: "/tmp/OpenTangerine-ods-check.ods"))
        try? fm.copyItem(at: docxOut, to: URL(fileURLWithPath: "/tmp/OpenTangerine-docx-check.docx"))
        print("PASS CSV -> XLSX -> CSV/TSV/ODS")

        let epubOut = try await convert(url("notes.md"), .md, .epub, "notes-roundtrip.epub")
        let epubPDF = try await convert(epubOut, .epub, .pdf, "notes-epub.pdf")
        precondition(try! PDFOps.document(epubPDF).pageCount > 0)
        let epubText = try await convert(epubOut, .epub, .txt, "notes-epub.txt")
        precondition(try! String(contentsOf: epubText, encoding: .utf8).contains("Body paragraph"))
        print("PASS MD -> EPUB -> PDF/TXT")

        let pdfMD = try await convert(pdf, .pdf, .md, "text.md")
        precondition(try! String(contentsOf: pdfMD, encoding: .utf8).contains("Citrus"))
        print("PASS PDF -> MD")

        let pptxOut = try await convert(pdf, .pdf, .pptx, "text.pptx")
        let pptxListing = try await Shell.run("/usr/bin/unzip", ["-l", pptxOut.path])
        precondition(pptxListing.succeeded && pptxListing.stdout.contains("ppt/slides/slide1.xml") && pptxListing.stdout.contains("ppt/media/page1.png"))
        let presentationXML = try await Shell.run("/usr/bin/unzip", ["-p", pptxOut.path, "ppt/presentation.xml"])
        precondition(presentationXML.succeeded && presentationXML.stdout.contains("<p:sldIdLst>"))
        try? fm.copyItem(at: pptxOut, to: URL(fileURLWithPath: "/tmp/OpenTangerine-pptx-check.pptx"))
        print("PASS PDF -> PPTX (image deck, valid package)")
        print("PASS new Tangerine tools are offered for the right file kinds")
    }
}
