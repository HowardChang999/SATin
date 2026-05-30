import AppKit
import Foundation

enum QuestionExportError: Error {
    case pdfContextCreationFailed
}

struct QuestionExportResult {
    let preview: String
    let fileURL: URL?
}

struct QuestionExporter {
    func export(questions: [Question], format: QuestionExportFormat, pdfMode: QuestionPDFExportMode = .questionsOnly) throws -> QuestionExportResult {
        switch format {
        case .json:
            return QuestionExportResult(preview: try toJSON(questions), fileURL: nil)
        case .csv:
            return QuestionExportResult(preview: toCSV(questions), fileURL: nil)
        case .markdown:
            return QuestionExportResult(preview: toMarkdown(questions, mode: pdfMode), fileURL: nil)
        case .pdf:
            let url = try toPDF(questions, mode: pdfMode)
            return QuestionExportResult(preview: "Exported \(questions.count) questions to \(url.path)", fileURL: url)
        }
    }

    private func toJSON(_ questions: [Question]) throws -> String {
        let mapped = questions.map { question in
            [
                "questionId": question.questionId,
                "assessment": question.assessment,
                "test": question.test,
                "domain": question.domain.rawValue,
                "skill": question.skill.rawValue,
                "difficulty": question.difficulty.rawValue,
                "questionText": question.questionText,
                "prompt": question.prompt,
                "choices": [
                    "A": question.choices.a,
                    "B": question.choices.b,
                    "C": question.choices.c,
                    "D": question.choices.d
                ],
                "correctAnswer": question.correctAnswer,
                "rationale": question.rationale,
                "figureAssets": question.figureAssets.map { $0.fileName },
                "sourcePdfName": question.sourcePdfName,
                "sourcePageRangeStart": question.sourcePageRangeStart,
                "sourcePageRangeEnd": question.sourcePageRangeEnd,
                "createdAt": ISO8601DateFormatter().string(from: question.createdAt)
            ] as [String: Any]
        }
        let data = try JSONSerialization.data(withJSONObject: mapped, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func toCSV(_ questions: [Question]) -> String {
        var lines = ["questionId,assessment,test,domain,skill,difficulty,questionText,prompt,choiceA,choiceB,choiceC,choiceD,correctAnswer,rationale,figureAssets,sourcePdfName,sourcePageRangeStart,sourcePageRangeEnd"]
        for question in questions {
            let columns = [
                question.questionId,
                question.assessment,
                question.test,
                question.domain.rawValue,
                question.skill.rawValue,
                question.difficulty.rawValue,
                question.questionText,
                question.prompt,
                question.choices.a,
                question.choices.b,
                question.choices.c,
                question.choices.d,
                question.correctAnswer,
                question.rationale,
                question.figureAssets.map(\.fileName).joined(separator: ";"),
                question.sourcePdfName,
                String(question.sourcePageRangeStart),
                String(question.sourcePageRangeEnd)
            ]
            lines.append(columns.map(escapeCSV).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private func toMarkdown(_ questions: [Question], mode: QuestionPDFExportMode) -> String {
        var lines = ["# SATin Question Bank Export", ""]
        for question in questions {
            lines.append("## \(question.questionId)")
            lines.append("\(question.domain.rawValue) | \(question.skill.rawValue) | \(question.difficulty.rawValue)")
            lines.append("")
            if !question.questionText.isEmpty {
                lines.append(question.questionText)
                lines.append("")
            }
            lines.append(question.prompt)
            lines.append("")
            lines.append("A. \(question.choices.a)")
            lines.append("B. \(question.choices.b)")
            lines.append("C. \(question.choices.c)")
            lines.append("D. \(question.choices.d)")
            if !question.figureAssets.isEmpty {
                lines.append("")
                lines.append("Figures: \(question.figureAssets.map(\.fileName).joined(separator: ", "))")
            }
            if mode.includesAnswers {
                lines.append("")
                lines.append("Answer: \(question.correctAnswer)")
            }
            if mode.includesRationales {
                lines.append("")
                lines.append("Rationale: \(question.rationale)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func toPDF(_ questions: [Question], mode: QuestionPDFExportMode) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SATin-Question-Export-\(UUID().uuidString.prefix(8)).pdf")
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 54
        let contentWidth = pageRect.width - margin * 2
        guard let context = CGContext(url as CFURL, mediaBox: nil, nil) else {
            throw QuestionExportError.pdfContextCreationFailed
        }

        var y = margin
        func beginPage() {
            context.beginPDFPage([kCGPDFContextMediaBox as String: pageRect] as CFDictionary)
            y = margin
        }
        func endPage() {
            context.endPDFPage()
        }
        func ensureSpace(_ height: CGFloat) {
            if y + height > pageRect.height - margin {
                endPage()
                beginPage()
            }
        }
        func drawText(_ text: String, font: NSFont, color: NSColor = .labelColor, spacingAfter: CGFloat = 8) {
            let attributed = NSAttributedString(
                string: text,
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraphStyle()
                ]
            )
            let height = attributed.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).height.rounded(.up)
            ensureSpace(height + spacingAfter)
            attributed.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: height), options: [.usesLineFragmentOrigin, .usesFontLeading])
            y += height + spacingAfter
        }
        func drawFigure(fileName: String) {
            let url = figureDirectory().appendingPathComponent(fileName)
            guard let image = NSImage(contentsOf: url) else { return }
            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let maxHeight: CGFloat = 180
            let scale = min(contentWidth / imageSize.width, maxHeight / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            ensureSpace(drawSize.height + 12)
            image.draw(in: CGRect(x: margin, y: y, width: drawSize.width, height: drawSize.height))
            y += drawSize.height + 12
        }

        beginPage()
        drawText("SATin Question Bank Export", font: .boldSystemFont(ofSize: 18), spacingAfter: 18)
        for question in questions {
            ensureSpace(120)
            drawText(question.questionId, font: .boldSystemFont(ofSize: 15), spacingAfter: 4)
            drawText("\(question.domain.rawValue) | \(question.skill.rawValue) | \(question.difficulty.rawValue)", font: .systemFont(ofSize: 10), color: .secondaryLabelColor, spacingAfter: 10)
            if !question.questionText.isEmpty {
                drawText(question.questionText, font: .systemFont(ofSize: 11), spacingAfter: 8)
            }
            for asset in question.figureAssets {
                drawFigure(fileName: asset.fileName)
            }
            drawText(question.prompt, font: .systemFont(ofSize: 11), spacingAfter: 8)
            drawText("A. \(question.choices.a)\nB. \(question.choices.b)\nC. \(question.choices.c)\nD. \(question.choices.d)", font: .systemFont(ofSize: 11), spacingAfter: 8)
            if mode.includesAnswers {
                drawText("Answer: \(question.correctAnswer)", font: .boldSystemFont(ofSize: 11), spacingAfter: 8)
            }
            if mode.includesRationales {
                drawText("Rationale: \(question.rationale)", font: .systemFont(ofSize: 11), spacingAfter: 12)
            }
            y += 12
        }
        endPage()
        context.closePDF()
        return url
    }

    private func paragraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.lineSpacing = 2
        return style
    }

    private func figureDirectory() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("ImportedFigures", isDirectory: true)
    }

    private func escapeCSV(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
