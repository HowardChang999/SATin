import Foundation

struct VocabularyExporter {
    func export(words: [SavedWord], format: VocabularyExportFormat) throws -> String {
        switch format {
        case .csv:
            return toCSV(words)
        case .json:
            return try toJSON(words)
        case .markdown:
            return toMarkdown(words)
        }
    }

    private func toCSV(_ words: [SavedWord]) -> String {
        var lines = ["word,definition,note,sourceQuestionId,savedAt,isMastered"]
        let formatter = ISO8601DateFormatter()
        for word in words {
            let columns = [
                escapeCSV(word.word),
                escapeCSV(word.definition),
                escapeCSV(word.notes),
                escapeCSV(word.sourceQuestionId),
                escapeCSV(formatter.string(from: word.savedAt)),
                word.isMastered ? "true" : "false"
            ]
            lines.append(columns.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private func toJSON(_ words: [SavedWord]) throws -> String {
        let mapped = words.map {
            [
                "word": $0.word,
                "definition": $0.definition,
                "notes": $0.notes,
                "sourceQuestionId": $0.sourceQuestionId,
                "savedAt": ISO8601DateFormatter().string(from: $0.savedAt),
                "isMastered": String($0.isMastered)
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: mapped, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func toMarkdown(_ words: [SavedWord]) -> String {
        var lines = ["# SATin Vocabulary Export", "", "| Word | Definition | Note | Source Question | Saved At | Mastered |", "|---|---|---|---|---|---|"]
        let formatter = ISO8601DateFormatter()
        for word in words {
            lines.append("| \(escapePipe(word.word)) | \(escapePipe(word.definition)) | \(escapePipe(word.notes)) | \(escapePipe(word.sourceQuestionId)) | \(formatter.string(from: word.savedAt)) | \(word.isMastered ? "Yes" : "No") |")
        }
        return lines.joined(separator: "\n")
    }

    private func escapeCSV(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func escapePipe(_ value: String) -> String {
        value.replacingOccurrences(of: "|", with: "\\|")
    }
}
