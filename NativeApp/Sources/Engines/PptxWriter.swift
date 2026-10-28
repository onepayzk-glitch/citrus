import AppKit
import Foundation
import PDFKit

/// Builds a PowerPoint deck with one full-bleed image per PDF page.
/// Pure OOXML so no Microsoft Office or Java runtime is required.
enum PptxWriter {
    private static let slideWidth = 12_192_000
    private static let slideHeight = 6_858_000

    static func writePDFSlides(_ pdf: URL, to destination: URL, progress: @escaping (Double) -> Void) async throws {
        let document = try PDFOps.document(pdf)
        let pageCount = document.pageCount
        guard pageCount > 0 else { throw OpenTangerineError.invalidInput("This PDF has no pages.") }
        let fm = FileManager.default
        let staging = fm.temporaryDirectory.appendingPathComponent("opentangerine-pptx-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        for path in ["_rels", "ppt/_rels", "ppt/slides/_rels", "ppt/slideMasters/_rels", "ppt/slideLayouts/_rels", "ppt/theme", "ppt/media"] {
            try fm.createDirectory(at: staging.appendingPathComponent(path), withIntermediateDirectories: true)
        }

        var slideOverrides = ""
        var slideRelationships = ""
        var slideList = ""
        var slides: [(xml: String, rels: String, image: String)] = []

        for index in 0..<pageCount {
            guard let page = document.page(at: index), let image = PDFRenderer.render(page: page, dpi: 150) else {
                throw OpenTangerineError.encodeFailed("PDF page \(index + 1)")
            }
            let imageURL = staging.appendingPathComponent("ppt/media/page\(index + 1).png")
            try ImageIOBridge.write(image, to: imageURL, format: .png)
            let slideNumber = index + 1
            let imageName = "page\(index + 1).png"

            // Fit the portrait page inside the 16:9 slide while keeping its aspect ratio.
            let imageAspect = Double(image.width) / Double(max(1, image.height))
            var width = Int(Double(slideHeight) * imageAspect)
            var height = slideHeight
            if width > slideWidth {
                width = slideWidth
                height = Int(Double(slideWidth) / imageAspect)
            }
            let x = (slideWidth - width) / 2
            let y = (slideHeight - height) / 2

            let slideXML = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
            <p:cSld><p:spTree>
            <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
            <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
            <p:pic><p:nvPicPr><p:cNvPr id="2" name="Page \(slideNumber)"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr>
            <p:blipFill><a:blip r:embed="rId1"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>
            <p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(width)" cy="\(height)"/></a:xfrm>
            <a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>
            </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
            """
            let slideRels = """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/\(imageName)"/>
            </Relationships>
            """
            slides.append((slideXML, slideRels, imageName))
            slideOverrides += """
            <Override PartName="/ppt/slides/slide\(slideNumber).xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
            """
            slideRelationships += """
            <Relationship Id="rId\(slideNumber + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide\(slideNumber).xml"/>
            """
            slideList += "<p:sldId id=\"\(255 + slideNumber)\" r:id=\"rId\(slideNumber + 1)\"/>"
            progress(Double(slideNumber) / Double(pageCount) * 0.7)
        }

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Default Extension="png" ContentType="image/png"/>
        <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
        <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>
        <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>
        <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>
        \(slideOverrides)
        </Types>
        """
        let rootRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
        </Relationships>
        """
        let presentation = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>
        <p:sldIdLst>\(slideList)</p:sldIdLst>
        <p:sldSz cx="\(slideWidth)" cy="\(slideHeight)"/><p:notesSz cx="6858000" cy="9144000"/>
        </p:presentation>
        """
        let presentationRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/>
        \(slideRelationships)
        <Relationship Id="rId\(slides.count + 2)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="theme/theme1.xml"/>
        </Relationships>
        """
        let master = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldMaster xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
        <p:cSld><p:spTree>
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
        </p:spTree></p:cSld>
        <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>
        <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>
        </p:sldMaster>
        """
        let masterRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme" Target="../theme/theme1.xml"/>
        </Relationships>
        """
        let layout = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <p:sldLayout xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" type="blank" preserve="1">
        <p:cSld name="Blank"><p:spTree>
        <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
        <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
        </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
        """
        let layoutRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/>
        </Relationships>
        """
        let theme = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Office">
        <a:themeElements>
        <a:clrScheme name="Office">
        <a:dk1><a:sysClr val="windowText" lastClr="000000"/></a:dk1><a:lt1><a:sysClr val="window" lastClr="FFFFFF"/></a:lt1>
        <a:dk2><a:srgbClr val="44546A"/></a:dk2><a:lt2><a:srgbClr val="E7E6E6"/></a:lt2>
        <a:accent1><a:srgbClr val="4472C4"/></a:accent1><a:accent2><a:srgbClr val="ED7D31"/></a:accent2>
        <a:accent3><a:srgbClr val="A5A5A5"/></a:accent3><a:accent4><a:srgbClr val="FFC000"/></a:accent4>
        <a:accent5><a:srgbClr val="5B9BD5"/></a:accent5><a:accent6><a:srgbClr val="70AD47"/></a:accent6>
        <a:hlink><a:srgbClr val="0563C1"/></a:hlink><a:folHlink><a:srgbClr val="954F72"/></a:folHlink>
        </a:clrScheme>
        <a:fontScheme name="Office">
        <a:majorFont><a:latin typeface="Calibri Light"/><a:ea typeface=""/><a:cs typeface=""/></a:majorFont>
        <a:minorFont><a:latin typeface="Calibri"/><a:ea typeface=""/><a:cs typeface=""/></a:minorFont>
        </a:fontScheme>
        <a:fmtScheme name="Office">
        <a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>
        <a:lnStyleLst><a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>
        <a:effectStyleLst><a:effectStyle><a:effectLst/></a:effectStyle></a:effectStyleLst>
        <a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>
        </a:fmtScheme>
        </a:themeElements>
        </a:theme>
        """

        try contentTypes.write(to: staging.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try rootRels.write(to: staging.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
        try presentation.write(to: staging.appendingPathComponent("ppt/presentation.xml"), atomically: true, encoding: .utf8)
        try presentationRels.write(to: staging.appendingPathComponent("ppt/_rels/presentation.xml.rels"), atomically: true, encoding: .utf8)
        try master.write(to: staging.appendingPathComponent("ppt/slideMasters/slideMaster1.xml"), atomically: true, encoding: .utf8)
        try masterRels.write(to: staging.appendingPathComponent("ppt/slideMasters/_rels/slideMaster1.xml.rels"), atomically: true, encoding: .utf8)
        try layout.write(to: staging.appendingPathComponent("ppt/slideLayouts/slideLayout1.xml"), atomically: true, encoding: .utf8)
        try layoutRels.write(to: staging.appendingPathComponent("ppt/slideLayouts/_rels/slideLayout1.xml.rels"), atomically: true, encoding: .utf8)
        try theme.write(to: staging.appendingPathComponent("ppt/theme/theme1.xml"), atomically: true, encoding: .utf8)

        var entries = [
            "[Content_Types].xml", "_rels/.rels", "ppt/presentation.xml", "ppt/_rels/presentation.xml.rels",
            "ppt/slideMasters/slideMaster1.xml", "ppt/slideMasters/_rels/slideMaster1.xml.rels",
            "ppt/slideLayouts/slideLayout1.xml", "ppt/slideLayouts/_rels/slideLayout1.xml.rels",
            "ppt/theme/theme1.xml",
        ]
        for (index, slide) in slides.enumerated() {
            let number = index + 1
            try slide.xml.write(to: staging.appendingPathComponent("ppt/slides/slide\(number).xml"), atomically: true, encoding: .utf8)
            try slide.rels.write(to: staging.appendingPathComponent("ppt/slides/_rels/slide\(number).xml.rels"), atomically: true, encoding: .utf8)
            entries.append("ppt/slides/slide\(number).xml")
            entries.append("ppt/slides/_rels/slide\(number).xml.rels")
            entries.append("ppt/media/\(slide.image)")
        }
        try await ZipTool.zipOrdered(directory: staging, entries: entries, to: destination)
        progress(1)
    }
}
