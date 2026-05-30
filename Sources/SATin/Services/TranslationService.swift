import Foundation

protocol RationaleTranslationService {
    func translate(_ text: String, to language: TranslationLanguage, quality: TranslationQuality) -> String
}

final class LocalMLXTranslationService: RationaleTranslationService {
    func translate(_ text: String, to language: TranslationLanguage, quality: TranslationQuality) -> String {
        "[Local \(quality.rawValue) translation to \(language.rawValue)]\n\n\(text)"
    }
}
