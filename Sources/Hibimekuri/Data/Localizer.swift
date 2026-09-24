import Foundation

/// Central translation tables for calendar chrome. Koyomi and
/// CalendarDay stay Japanese-only internally (that's the verified,
/// canonical data); this layer only decides how to *display* it.
/// Japanese and English are written inline at each call site; Italian,
/// French and Spanish are looked up by the English text (see
/// `Translations`). Japanese almanac terms stay romanized in every
/// non-Japanese language, the way they're usually written in the West.
enum Localizer {

    // MARK: - Weekday / month / era

    private static let weekdayJA = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
    private static let weekdayEN = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let monthEN = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let miniWeekdayJA = ["日", "月", "火", "水", "木", "金", "土"]
    private static let miniWeekdayEN = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    static func weekday(index: Int, language: AppLanguage) -> String {
        switch language {
        case .japanese: weekdayJA[index]
        case .english: weekdayEN[index]
        default: symbols(language).standaloneWeekdaySymbols[index].capitalized(with: language.locale)
        }
    }

    static func month(number: Int, language: AppLanguage) -> String {
        switch language {
        case .japanese: "\(number)月"
        case .english: monthEN[number - 1]
        default: symbols(language).standaloneMonthSymbols[number - 1].capitalized(with: language.locale)
        }
    }

    static func miniWeekday(index: Int, language: AppLanguage) -> String {
        switch language {
        case .japanese: miniWeekdayJA[index]
        case .english: miniWeekdayEN[index]
        default: String(symbols(language).shortStandaloneWeekdaySymbols[index].prefix(2)).capitalized(with: language.locale)
        }
    }

    private static func symbols(_ language: AppLanguage) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        return formatter
    }

    static func era(_ ja: String, language: AppLanguage) -> String {
        guard language != .japanese else { return ja }
        let map = ["令和": "Reiwa", "平成": "Heisei", "昭和": "Showa"]
        for (jaName, enName) in map where ja.hasPrefix(jaName) {
            let yearPart = ja.dropFirst(jaName.count).replacingOccurrences(of: "年", with: "")
            return "\(enName) \(yearPart)"
        }
        return ja
    }

    static func monthKind(_ ja: String, language: AppLanguage) -> String {
        guard language != .japanese else { return ja }
        return ja == "大" ? t(ja, "31 days", language: language) : t(ja, "30 days", language: language)
    }

    // MARK: - Almanac field labels

    static func fieldLabel(_ ja: String, language: AppLanguage) -> String {
        guard language != .japanese else { return ja }
        let map = ["干支": "Kanshi", "六曜": "Rokuyō", "旧暦": "Lunar date", "中段": "Jūnichoku"]
        guard let en = map[ja] else { return ja }
        return t(ja, en, language: language)
    }

    // MARK: - Kanshi (day stem + branch)

    private static let stemRomaji: [String: String] = [
        "甲": "Kinoe", "乙": "Kinoto", "丙": "Hinoe", "丁": "Hinoto", "戊": "Tsuchinoe",
        "己": "Tsuchinoto", "庚": "Kanoe", "辛": "Kanoto", "壬": "Mizunoe", "癸": "Mizunoto"
    ]
    private static let branchRomaji: [String: String] = [
        "子": "Ne", "丑": "Ushi", "寅": "Tora", "卯": "U", "辰": "Tatsu", "巳": "Mi",
        "午": "Uma", "未": "Hitsuji", "申": "Saru", "酉": "Tori", "戌": "Inu", "亥": "I"
    ]

    static func kanshi(_ ja: String, language: AppLanguage) -> String {
        guard language != .japanese, ja.count == 2 else { return ja }
        let chars = Array(ja)
        let stem = stemRomaji[String(chars[0])] ?? String(chars[0])
        let branch = branchRomaji[String(chars[1])] ?? String(chars[1])
        return "\(stem)-\(branch)"
    }

    // MARK: - Rokuyō

    private static let rokuyoRomaji: [String: String] = [
        "大安": "Taian", "赤口": "Shakkō", "先勝": "Senshō",
        "友引": "Tomobiki", "先負": "Senpu", "仏滅": "Butsumetsu"
    ]

    static func rokuyo(_ ja: String, language: AppLanguage) -> String {
        guard language != .japanese else { return ja }
        return rokuyoRomaji[ja] ?? ja
    }

    // MARK: - Jūnichoku

    private static let junichokuRomaji: [String: String] = [
        "建": "Tatsu", "除": "Nozoku", "満": "Mitsu", "平": "Taira", "定": "Sadan", "執": "Toru",
        "破": "Yaburu", "危": "Ayabu", "成": "Naru", "納": "Osan", "開": "Hiraku", "閉": "Tozu"
    ]

    static func junichoku(_ ja: String, language: AppLanguage) -> String {
        guard language != .japanese else { return ja }
        return junichokuRomaji[ja] ?? ja
    }

    // MARK: - Kyūreki (old lunar date)

    static func kyureki(month: Int, day: Int, isLeap: Bool, language: AppLanguage) -> String {
        switch language {
        case .japanese: return "\(isLeap ? "閏" : "")\(month)月\(day)日"
        case .english: return "\(isLeap ? "Leap " : "")Lunar \(month)/\(day)"
        // Day before month, as dates are written in these languages.
        case .italian: return "Lunare \(day)/\(month)\(isLeap ? " (intercalare)" : "")"
        case .french: return "Lunaire \(day)/\(month)\(isLeap ? " (intercalaire)" : "")"
        case .spanish: return "Lunar \(day)/\(month)\(isLeap ? " (intercalar)" : "")"
        }
    }

    // MARK: - Moon phase

    private static let moonPhaseEN: [String: String] = [
        "新月": "New moon", "三日月": "Waxing crescent", "上弦": "First quarter",
        "十三夜": "Waxing gibbous", "満月": "Full moon", "十六夜": "Waning gibbous",
        "下弦": "Last quarter", "有明": "Waning crescent"
    ]

    static func moonPhase(_ ja: String, language: AppLanguage) -> String {
        guard language != .japanese, let en = moonPhaseEN[ja] else { return ja }
        return t(ja, en, language: language)
    }

    // MARK: - UI chrome

    /// Italian, French and Spanish come from `Translations`, keyed by
    /// `en`; a missing entry falls back to English rather than showing
    /// nothing.
    static func t(_ ja: String, _ en: String, language: AppLanguage) -> String {
        switch language {
        case .japanese: ja
        case .english: en
        case .italian: Translations.italian[en] ?? en
        case .french: Translations.french[en] ?? en
        case .spanish: Translations.spanish[en] ?? en
        }
    }

    /// For strings with interpolated values, which can't be looked up
    /// by their English text.
    static func t(_ ja: String, _ en: String, it: String, fr: String, es: String, language: AppLanguage) -> String {
        switch language {
        case .japanese: ja
        case .english: en
        case .italian: it
        case .french: fr
        case .spanish: es
        }
    }
}
