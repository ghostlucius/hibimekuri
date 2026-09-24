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

    private static let junichokuBlurbIT: [String: String] = [
        "建": "Si dice propizio per iniziare cose nuove",
        "除": "Si dice propizio per pulire e seminare",
        "満": "Si dice un giorno di abbondanza",
        "平": "Si dice propizio perché le cose si appianino",
        "定": "Si dice propizio per contratti e accordi",
        "執": "Si dice propizio per cerimonie e festeggiamenti",
        "破": "Si dice propizio per superare ostacoli e chiudere contese",
        "危": "Si dice un giorno di prudenza in ogni cosa",
        "成": "Si dice propizio perché le cose giungano a compimento",
        "納": "Si dice propizio per raccolti e consegne",
        "開": "Si dice propizio per ogni festeggiamento",
        "閉": "Si dice propizio per riscuotere denaro o chiudere conti"
    ]

    private static let junichokuBlurbFR: [String: String] = [
        "建": "Réputé propice aux commencements",
        "除": "Réputé propice au ménage et aux semailles",
        "満": "Réputé jour d'abondance",
        "平": "Réputé propice à l'apaisement des choses",
        "定": "Réputé propice aux contrats et aux accords",
        "執": "Réputé propice aux cérémonies et aux fêtes",
        "破": "Réputé propice à franchir les obstacles et régler les différends",
        "危": "Réputé jour de prudence en toute chose",
        "成": "Réputé propice à l'aboutissement des projets",
        "納": "Réputé propice aux récoltes et aux livraisons",
        "開": "Réputé propice aux célébrations en général",
        "閉": "Réputé propice aux encaissements ou à la clôture des comptes"
    ]

    private static let junichokuBlurbES: [String: String] = [
        "建": "Se dice propicio para empezar cosas nuevas",
        "除": "Se dice propicio para limpiar y sembrar",
        "満": "Se dice un día de abundancia",
        "平": "Se dice propicio para que las cosas se calmen",
        "定": "Se dice propicio para contratos y acuerdos",
        "執": "Se dice propicio para ceremonias y celebraciones",
        "破": "Se dice propicio para superar obstáculos y zanjar disputas",
        "危": "Se dice un día para la prudencia en todo",
        "成": "Se dice propicio para que las cosas lleguen a buen término",
        "納": "Se dice propicio para cosechas y entregas",
        "開": "Se dice propicio para celebraciones en general",
        "閉": "Se dice propicio para cobrar dinero o cerrar cuentas"
    ]

    static func junichokuBlurb(_ junichokuJA: String, language: AppLanguage) -> String? {
        switch language {
        case .japanese: junichokuBlurbJA[junichokuJA]
        case .english: junichokuBlurbEN[junichokuJA]
        case .italian: junichokuBlurbIT[junichokuJA]
        case .french: junichokuBlurbFR[junichokuJA]
        case .spanish: junichokuBlurbES[junichokuJA]
        }
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

    private static let observancesIT: [String: String] = [
        "1-1": "Capodanno",
        "1-7": "Nanakusa (sette erbe)",
        "2-3": "Setsubun",
        "2-11": "Giornata della fondazione nazionale",
        "2-23": "Compleanno dell'Imperatore",
        "3-3": "Hinamatsuri (festa delle bambole)",
        "4-29": "Giornata Shōwa",
        "5-3": "Giornata della Costituzione",
        "5-5": "Giornata dei bambini",
        "7-7": "Tanabata",
        "8-11": "Giornata della montagna",
        "8-15": "Anniversario della fine della guerra",
        "11-3": "Giornata della cultura",
        "11-15": "Shichi-Go-San",
        "11-23": "Festa del ringraziamento per il lavoro",
        "12-24": "Vigilia di Natale",
        "12-31": "San Silvestro"
    ]

    private static let observancesFR: [String: String] = [
        "1-1": "Jour de l'an",
        "1-7": "Nanakusa (sept herbes)",
        "2-3": "Setsubun",
        "2-11": "Fête de la fondation nationale",
        "2-23": "Anniversaire de l'Empereur",
        "3-3": "Hinamatsuri (fête des poupées)",
        "4-29": "Jour de Shōwa",
        "5-3": "Jour de la Constitution",
        "5-5": "Fête des enfants",
        "7-7": "Tanabata",
        "8-11": "Jour de la montagne",
        "8-15": "Commémoration de la fin de la guerre",
        "11-3": "Jour de la culture",
        "11-15": "Shichi-Go-San",
        "11-23": "Fête du travail",
        "12-24": "Veille de Noël",
        "12-31": "Saint-Sylvestre"
    ]

    private static let observancesES: [String: String] = [
        "1-1": "Año Nuevo",
        "1-7": "Nanakusa (siete hierbas)",
        "2-3": "Setsubun",
        "2-11": "Día de la Fundación Nacional",
        "2-23": "Cumpleaños del Emperador",
        "3-3": "Hinamatsuri (fiesta de las muñecas)",
        "4-29": "Día de Shōwa",
        "5-3": "Día de la Constitución",
        "5-5": "Día de los Niños",
        "7-7": "Tanabata",
        "8-11": "Día de la Montaña",
        "8-15": "Aniversario del fin de la guerra",
        "11-3": "Día de la Cultura",
        "11-15": "Shichi-Go-San",
        "11-23": "Día de Acción de Gracias por el Trabajo",
        "12-24": "Nochebuena",
        "12-31": "Nochevieja"
    ]

    static func observance(month: Int, day: Int, language: AppLanguage) -> String? {
        let key = "\(month)-\(day)"
        switch language {
        case .japanese: return observancesJA[key]
        case .english: return observancesEN[key]
        case .italian: return observancesIT[key]
        case .french: return observancesFR[key]
        case .spanish: return observancesES[key]
        }
    }
}
