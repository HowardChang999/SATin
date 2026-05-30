import Foundation
import PDFKit
import CoreGraphics
import AppKit

struct NormalizedRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
}

struct ParsedQuestionDraft: Identifiable {
    var id = UUID()
    var questionId: String = ""
    var assessment: String = "SAT"
    var test: String = TestType.readingAndWriting.rawValue
    var domain: Domain = .informationAndIdeas
    var skill: Skill = .commandOfEvidence
    var difficulty: Difficulty = .medium
    var questionText: String = ""
    var prompt: String = ""
    var choices: ChoiceSet = .init(a: "", b: "", c: "", d: "")
    var correctAnswer: String = ""
    var rationale: String = ""
    var sourcePdfName: String = ""
    var sourcePdfPath: String = ""
    var sourcePageRange: ClosedRange<Int> = 1...1
    var figureAssets: [FigureAsset] = []
    var cropRect: NormalizedRect = .full
}

final class PDFImportService {
    func parse(pdfURL: URL) -> [ParsedQuestionDraft] {
        guard let document = PDFDocument(url: pdfURL) else { return [] }
        let fullText = extractText(document)
        var drafts = parseFromRawText(fullText, sourcePdfName: pdfURL.lastPathComponent)

        let pageMap = questionPageRangeMap(document: document)
        for i in drafts.indices {
            drafts[i].sourcePdfPath = pdfURL.path
            if let range = pageMap[drafts[i].questionId] {
                drafts[i].sourcePageRange = range
            }
        }
        return drafts
    }

    func parseFromRawText(_ text: String, sourcePdfName: String) -> [ParsedQuestionDraft] {
        let blocks = splitQuestionBlocks(text)
        return blocks.compactMap { parseQuestionBlock($0, sourcePdfName: sourcePdfName) }
    }

    func splitQuestionBlocks(_ text: String) -> [String] {
        let pattern = "(?=Question ID:)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex?.matches(in: text, range: range) ?? []
        guard !matches.isEmpty else { return [] }

        var results: [String] = []
        for i in matches.indices {
            let start = matches[i].range.location
            let end = (i + 1 < matches.count) ? matches[i + 1].range.location : (text as NSString).length
            let segment = (text as NSString).substring(with: NSRange(location: start, length: end - start))
            results.append(segment)
        }
        return results
    }


    func pagePreviewImage(pdfPath: String, page1Based: Int) -> NSImage? {
        let url = URL(fileURLWithPath: pdfPath)
        guard let doc = PDFDocument(url: url), page1Based > 0, page1Based <= doc.pageCount,
              let page = doc.page(at: page1Based - 1) else { return nil }
        return page.thumbnail(of: NSSize(width: 1100, height: 1400), for: .mediaBox)
    }

    func generateFigureAsset(
        pdfPath: String,
        page1Based: Int,
        cropRect: NormalizedRect,
        questionId: String
    ) -> FigureAsset? {
        let url = URL(fileURLWithPath: pdfPath)
        guard let doc = PDFDocument(url: url), page1Based > 0, page1Based <= doc.pageCount,
              let page = doc.page(at: page1Based - 1) else { return nil }

        let image = page.thumbnail(of: NSSize(width: 2000, height: 2600), for: .mediaBox)
        guard let cropped = crop(image: image, normalizedRect: cropRect),
              let tiff = cropped.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return nil
        }

        let dir = figureDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileName = "\(questionId)_figure_\(UUID().uuidString.prefix(6)).png"
        let fileURL = dir.appendingPathComponent(fileName)
        do {
            try pngData.write(to: fileURL)
            return FigureAsset(type: "image", fileName: fileName)
        } catch {
            return nil
        }
    }

    func figureAbsolutePath(fileName: String) -> String {
        figureDirectory().appendingPathComponent(fileName).path
    }

    private func figureDirectory() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("ImportedFigures", isDirectory: true)
    }

    private func crop(image: NSImage, normalizedRect: NormalizedRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        let normalizedWidth = max(0.01, min(1, normalizedRect.width))
        let normalizedHeight = max(0.01, min(1, normalizedRect.height))
        let normalizedX = max(0, min(1 - normalizedWidth, normalizedRect.x))
        let normalizedY = max(0, min(1 - normalizedHeight, normalizedRect.y))
        let rect = CGRect(
            x: normalizedX * w,
            y: normalizedY * h,
            width: normalizedWidth * w,
            height: normalizedHeight * h
        ).integral.intersection(CGRect(x: 0, y: 0, width: w, height: h))

        guard !rect.isNull, !rect.isEmpty, let cropped = cgImage.cropping(to: rect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
    }

    private func extractText(_ document: PDFDocument) -> String {
        var buffer = ""
        for idx in 0..<document.pageCount {
            if let page = document.page(at: idx), let content = page.string {
                buffer += content + "\n"
            }
        }
        return buffer
    }

    private func questionPageRangeMap(document: PDFDocument) -> [String: ClosedRange<Int>] {
        var found: [(id: String, page: Int)] = []
        let pattern = try? NSRegularExpression(pattern: "Question ID:\\s*([a-zA-Z0-9_-]+)", options: [.caseInsensitive])

        for idx in 0..<document.pageCount {
            guard let page = document.page(at: idx), let text = page.string, let pattern else { continue }
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let m = pattern.firstMatch(in: text, range: range), m.numberOfRanges > 1 {
                let id = ns.substring(with: m.range(at: 1))
                found.append((id: id, page: idx + 1))
            }
        }

        var map: [String: ClosedRange<Int>] = [:]
        for i in found.indices {
            let start = found[i].page
            let end = (i + 1 < found.count) ? max(start, found[i + 1].page - 1) : document.pageCount
            map[found[i].id] = start...end
        }
        return map
    }

    private func parseQuestionBlock(_ block: String, sourcePdfName: String) -> ParsedQuestionDraft? {
        guard let qid = firstCapture(in: block, pattern: "Question ID:\\s*([a-zA-Z0-9_-]+)") else { return nil }
        var draft = ParsedQuestionDraft()
        draft.questionId = qid
        draft.sourcePdfName = sourcePdfName

        if let metadata = parseMetadataLine(from: block) {
            if let domain = Domain(rawValue: metadata.domain) {
                draft.domain = domain
            }
            if let skill = Skill(rawValue: metadata.skill) {
                draft.skill = skill
            }
            if let difficulty = difficultyFromLooseString(metadata.difficulty) {
                draft.difficulty = difficulty
            }
        }

        draft.correctAnswer = firstCapture(in: block, pattern: "Correct Answer:\\s*([ABCD])") ?? ""

        draft.choices = .init(
            a: captureChoice("A", in: block),
            b: captureChoice("B", in: block),
            c: captureChoice("C", in: block),
            d: captureChoice("D", in: block)
        )

        draft.rationale = firstCapture(in: block, pattern: "Rationale\\s*([\\s\\S]*)")?
            .replacingOccurrences(of: "\\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if let qSection = firstCapture(in: block, pattern: "Question\\s*([\\s\\S]*?)\\s*Answer") {
            draft.questionText = qSection.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return draft
    }


    private func parseMetadataLine(from block: String) -> (domain: String, skill: String, difficulty: String)? {
        let lines = block.components(separatedBy: .newlines)
        let candidate = lines.first { line in
            line.localizedCaseInsensitiveContains("Reading and Writing") && line.contains("|")
        }
        guard let candidate else { return nil }

        let parts = candidate
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Expected: SAT | Reading and Writing | Domain | Skill | Difficulty
        guard parts.count >= 5 else { return nil }
        return (domain: parts[2], skill: parts[3], difficulty: parts[4])
    }

    private func difficultyFromLooseString(_ raw: String) -> Difficulty? {
        let lowered = raw.lowercased()
        if lowered.contains("easy") { return .easy }
        if lowered.contains("medium") { return .medium }
        if lowered.contains("hard") { return .hard }
        return Difficulty(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func captureChoice(_ letter: String, in block: String) -> String {
        let options = "ABCD".map(String.init)
        guard let idx = options.firstIndex(of: letter) else { return "" }
        let next = idx + 1 < options.count ? options[idx + 1] : nil
        let pattern: String
        if let next {
            pattern = "\\b\(letter)\\.\\s*([\\s\\S]*?)\\s*\\b\(next)\\."
        } else {
            pattern = "\\b\(letter)\\.\\s*([\\s\\S]*?)\\s*Correct Answer:"
        }
        return firstCapture(in: block, pattern: pattern)?
            .replacingOccurrences(of: "\\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else { return nil }
        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound else { return nil }
        return nsText.substring(with: captureRange)
    }
}
