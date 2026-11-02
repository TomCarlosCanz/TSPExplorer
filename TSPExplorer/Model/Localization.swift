import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english, german

    var id: String { rawValue }

    var title: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        }
    }

    var locale: Locale {
        Locale(identifier: self == .german ? "de_DE" : "en_US")
    }
}

/// The app's language, chosen in Settings independently of the device language.
/// Views pick it up automatically because reading it is tracked by Observation.
@Observable
final class Localization {
    static let shared = Localization()

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }

    private init() {
        language = UserDefaults.standard.string(forKey: "language").flatMap(AppLanguage.init) ?? .english
    }
}

/// Picks the English or German version of a text.
func tr(_ english: String, _ german: String) -> String {
    Localization.shared.language == .german ? german : english
}
