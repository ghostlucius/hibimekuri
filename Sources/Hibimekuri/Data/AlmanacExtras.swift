import Foundation

/// Curated flavor text — general folklore associations, not precise
/// religious or legal claims. Presented as calendar decoration, matching
/// how printed koyomi calendars caption each day.
enum AlmanacExtras {

    /// Short blurb of what each jūnichoku term is traditionally associated with.
    private static let junichokuBlurbJA: [String: String] = [
        "建": "何かを始めるのに良いとされる日",
        "除": "掃除や種まきに良いとされる日",
        "満": "万事満ち足りるとされる日",
        "平": "物事が平らかになるとされる日",
        "定": "善悪が定まる、契約ごとに良いとされる日",
        "執": "祭祀や祝い事に良いとされる日",
        "破": "物事を突破する、決着ごとに向くとされる日",
        "危": "万事に慎み深くあるべきとされる日",
        "成": "物事が成就するとされる日",
        "納": "収穫や納品に良いとされる日",
        "開": "祝い事全般に良いとされる日",
        "閉": "金銭の受け取りなどに向くとされる日"
    ]

    private static let junichokuBlurbEN: [String: String] = [
        "建": "Said to favor starting new things",
        "除": "Said to favor cleaning and sowing seeds",
        "満": "Said to be a day of abundance",
        "平": "Said to favor things settling evenly",
        "定": "Said to favor contracts and settling matters",
        "執": "Said to favor ceremonies and celebrations",
        "破": "Said to favor breaking through, settling disputes",
        "危": "Said to call for caution in all things",
        "成": "Said to favor things coming to fruition",
        "納": "Said to favor harvesting and delivery",
        "開": "Said to favor celebrations generally",
        "閉": "Said to favor receiving money or closing accounts"
    ]

    static func junichokuBlurb(_ junichokuJA: String, language: AppLanguage) -> String? {
        language == .japanese ? junichokuBlurbJA[junichokuJA] : junichokuBlurbEN[junichokuJA]
    }

    /// Fixed-date annual observances only (no floating "nth weekday" holidays,
    /// since those require locale-aware rules beyond this app's scope).
    private static let observancesJA: [String: String] = [
        "1-1": "元日",
        "1-7": "七草",
        "2-3": "節分",
        "2-11": "建国記念の日",
        "2-23": "天皇誕生日",
        "3-3": "ひな祭り",
        "4-29": "昭和の日",
        "5-3": "憲法記念日",
        "5-5": "こどもの日",
        "7-7": "七夕",
        "8-11": "山の日",
        "8-15": "終戦の日",
        "11-3": "文化の日",
        "11-15": "七五三",
        "11-23": "勤労感謝の日",
        "12-24": "クリスマスイブ",
        "12-31": "大晦日"
    ]

    private static let observancesEN: [String: String] = [
        "1-1": "New Year's Day",
        "1-7": "Nanakusa (seven herbs)",
        "2-3": "Setsubun",
        "2-11": "National Foundation Day",
        "2-23": "Emperor's Birthday",
        "3-3": "Hinamatsuri (Doll Festival)",
        "4-29": "Shōwa Day",
        "5-3": "Constitution Memorial Day",
        "5-5": "Children's Day",
        "7-7": "Tanabata",
        "8-11": "Mountain Day",
        "8-15": "End of WWII Memorial Day",
        "11-3": "Culture Day",
        "11-15": "Shichi-Go-San",
        "11-23": "Labor Thanksgiving Day",
        "12-24": "Christmas Eve",
        "12-31": "New Year's Eve"
    ]

    static func observance(month: Int, day: Int, language: AppLanguage) -> String? {
        let key = "\(month)-\(day)"
        return language == .japanese ? observancesJA[key] : observancesEN[key]
    }
}
