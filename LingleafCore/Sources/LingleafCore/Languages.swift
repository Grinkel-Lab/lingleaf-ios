import Foundation

/// Which language words are translated into. Mirrors `TranslationLanguages` in lingleaf-android.
public enum TranslationLanguages {
    /// Languages Apple Translation can translate English into.
    public static let supported = [
        "es", "pt", "fr", "it", "de", "nl", "pl", "uk", "ru", "tr", "ar", "hi", "id", "vi", "th", "zh-Hans", "ja", "ko",
    ]

    /// Offered on the first word card when no language could be picked, after the region's language.
    public static let suggested = ["es", "pt", "fr", "zh-Hans", "ar"]

    /// How many languages the first word card offers (a "More languages" chip follows them).
    public static let maxSuggestions = 5

    /// The first language in the user's preferred-language list (in order) that is
    /// supported and not English. Chinese in any script maps to Simplified Chinese.
    /// Nil when there is none: the app then asks.
    public static func pick(preferred: [String], supported: [String]) -> String? {
        for identifier in preferred {
            let code = languageCode(identifier)
            guard code != "en" else { continue }
            let candidate = code == "zh" ? "zh-Hans" : code
            if supported.contains(candidate) { return candidate }
        }
        return nil
    }

    /// The languages offered on the first word card: the region's main language when
    /// supported, then `suggested` without repeats, at most `maxSuggestions`.
    public static func suggestions(region: String?, supported: [String]) -> [String] {
        var result: [String] = []
        if let region, let language = regionLanguages[region.uppercased()], supported.contains(language) {
            result.append(language)
        }
        for language in suggested where !result.contains(language) && supported.contains(language) {
            result.append(language)
        }
        return Array(result.prefix(maxSuggestions))
    }

    /// "pt-BR", "pt_BR", "PT" → "pt".
    static func languageCode(_ identifier: String) -> String {
        String(identifier.prefix { $0 != "-" && $0 != "_" }).lowercased()
    }

    /// Main language of a country (ISO 3166 code), for the supported languages only.
    static let regionLanguages: [String: String] = {
        let groups: [String: [String]] = [
            "es": ["ES", "MX", "AR", "CO", "CL", "PE", "VE", "EC", "GT", "CU", "BO", "DO", "HN", "PY", "SV", "NI",
                   "CR", "PA", "UY", "PR", "GQ"],
            "pt": ["BR", "PT", "AO", "MZ", "CV", "GW", "ST", "TL"],
            "fr": ["FR", "MC", "SN", "CI", "CM", "ML", "BF", "NE", "TD", "GN", "BJ", "TG", "CD", "CG", "GA", "MG", "HT", "LU"],
            "it": ["IT", "SM", "VA"],
            "de": ["DE", "AT", "CH", "LI"],
            "nl": ["NL", "BE", "SR"],
            "pl": ["PL"],
            "uk": ["UA"],
            "ru": ["RU", "BY", "KZ", "KG"],
            "tr": ["TR"],
            "ar": ["EG", "SA", "AE", "MA", "DZ", "TN", "LY", "IQ", "JO", "LB", "SY", "YE", "OM", "KW", "QA", "BH",
                   "SD", "PS", "MR"],
            "hi": ["IN"],
            "id": ["ID"],
            "vi": ["VN"],
            "th": ["TH"],
            "zh-Hans": ["CN", "TW", "HK", "MO", "SG"],
            "ja": ["JP"],
            "ko": ["KR"],
        ]
        var map: [String: String] = [:]
        for (language, regions) in groups {
            for region in regions { map[region] = language }
        }
        return map
    }()
}
