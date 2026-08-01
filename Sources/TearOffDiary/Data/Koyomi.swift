import Foundation

/// Traditional Japanese almanac (koyomi) math: sexagenary day cycle, the
/// six-day rokuyō fortune cycle, the twelve-day jūnichoku cycle, the old
/// lunisolar calendar date, and moon phase.
///
/// These are astronomical approximations (low-precision solar longitude
/// and Meeus' new-moon series), the same class of method most consumer
/// koyomi apps use — not the official ephemeris the National Astronomical
/// Observatory of Japan publishes. Expect rare single-day drift right at
/// a new-moon or solar-term boundary. All lunisolar math is anchored to
/// Japan Standard Time, per convention, regardless of the device's locale.
enum Koyomi {

    struct Day {
        let kanshi: String
        let rokuyo: String
        let junichoku: String
        let kyureki: (month: Int, day: Int, isLeap: Bool)
        let moonPhaseName: String
        let moonPhaseSymbol: String
        let monthKind: String // 大 (31 days) or 小
    }

    private static var jstCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }()

    // MARK: - Public entry point

    static func day(for date: Date) -> Day {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day,
              let noonJST = jstCalendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) else {
            return Day(kanshi: "—", rokuyo: "—", junichoku: "—", kyureki: (1, 1, false), moonPhaseName: "—", moonPhaseSymbol: "moon", monthKind: "小")
        }

        let jdnValue = jdn(y, m, d)
        let kanshiStr = kanshiString(jdn: jdnValue)

        let targetJD = julianDay(fromDate: noonJST)
        let (kMonthStart, monthNumber, isLeap, lunarDay) = lunarDate(targetJD: targetJD, targetDayStart: jstCalendar.startOfDay(for: noonJST))

        let rokuyoStr = rokuyo(month: monthNumber, day: lunarDay)
        let branchIdx = (jdnValue - 11 + 12000) % 12
        let junichokuStr = junichoku(dayBranchIndex: branchIdx, targetJD: targetJD)

        let (phaseName, phaseSymbol) = moonPhase(lunarDay: lunarDay)

        let daysInMonth = jstCalendar.range(of: .day, in: .month, for: noonJST)?.count ?? 30
        let monthKind = daysInMonth >= 31 ? "大" : "小"

        _ = kMonthStart
        return Day(
            kanshi: kanshiStr,
            rokuyo: rokuyoStr,
            junichoku: junichokuStr,
            kyureki: (monthNumber, lunarDay, isLeap),
            moonPhaseName: phaseName,
            moonPhaseSymbol: phaseSymbol,
            monthKind: monthKind
        )
    }

    // MARK: - Julian day

    private static func jdn(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let a = (14 - m) / 12
        let yy = y + 4800 - a
        let mm = m + 12 * a - 3
        return d + (153 * mm + 2) / 5 + 365 * yy + yy / 4 - yy / 100 + yy / 400 - 32045
    }

    private static func julianDay(fromDate date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    private static func date(fromJD jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2440587.5) * 86400.0)
    }

    private static func norm360(_ d: Double) -> Double {
        var x = d.truncatingRemainder(dividingBy: 360)
        if x < 0 { x += 360 }
        return x
    }

    // MARK: - Kanshi (sexagenary day cycle)

    private static let stems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    private static let branches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]

    private static func kanshiString(jdn: Int) -> String {
        let gz = ((jdn - 11) % 60 + 60) % 60
        return stems[gz % 10] + branches[gz % 12]
    }

    // MARK: - Solar longitude (Meeus, low precision Sun)

    private static func solarLongitude(jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        let L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T
        let M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) * .pi / 180
        let C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(M)
            + (0.019993 - 0.000101 * T) * sin(2 * M)
            + 0.000289 * sin(3 * M)
        return norm360(L0 + C)
    }

    private static func findLongitudeCrossing(target: Double, near: Double) -> Double {
        var jd = near
        for _ in 0..<8 {
            let lon = solarLongitude(jd: jd)
            var diff = target - lon
            if diff > 180 { diff -= 360 }
            if diff < -180 { diff += 360 }
            jd += diff * 365.2422 / 360.0
        }
        return jd
    }

    // MARK: - New moon (Meeus ch. 49, truncated correction series)

    private static func newMoonJD(k: Double) -> Double {
        let T = k / 1236.85
        let JDE = 2451550.09766 + 29.530588861 * k + 0.00015437 * T * T
            - 0.000000150 * T * T * T + 0.00000000073 * T * T * T * T
        let E = 1 - 0.002516 * T - 0.0000074 * T * T
        let M = norm360(2.5534 + 29.10535669 * k - 0.0000218 * T * T - 0.00000011 * T * T * T) * .pi / 180
        let Mp = norm360(201.5643 + 385.81693528 * k + 0.0107582 * T * T + 0.00001238 * T * T * T - 0.000000058 * T * T * T * T) * .pi / 180
        let F = norm360(160.7108 + 390.67050284 * k - 0.0016118 * T * T - 0.00000227 * T * T * T + 0.000000011 * T * T * T * T) * .pi / 180
        let Omega = norm360(124.7746 - 1.56375588 * k + 0.0020672 * T * T + 0.00000215 * T * T * T) * .pi / 180

        var corr = 0.0
        corr += -0.40720 * sin(Mp)
        corr += 0.17241 * E * sin(M)
        corr += 0.01608 * sin(2 * Mp)
        corr += 0.01039 * sin(2 * F)
        corr += 0.00739 * E * sin(Mp - M)
        corr += -0.00514 * E * sin(Mp + M)
        corr += 0.00208 * E * E * sin(2 * M)
        corr += -0.00111 * sin(Mp - 2 * F)
        corr += -0.00057 * sin(Mp + 2 * F)
        corr += 0.00056 * E * sin(2 * Mp + M)
        corr += -0.00042 * sin(3 * Mp)
        corr += 0.00042 * E * sin(M + 2 * F)
        corr += 0.00038 * E * sin(M - 2 * F)
        corr += -0.00024 * E * sin(2 * Mp - M)
        corr += -0.00017 * sin(Omega)

        return JDE + corr
    }

    private static func lunationEstimateK(year: Int, month: Int) -> Double {
        let yearsFrom2000 = Double(year - 2000) + Double(month - 1) / 12.0
        return (yearsFrom2000 * 12.3685).rounded()
    }

    private static func jstDayStart(ofJD jd: Double) -> Date {
        jstCalendar.startOfDay(for: date(fromJD: jd))
    }

    // MARK: - Lunar date (kyūreki) via winter-solstice-anchored month numbering

    private static func lunarDate(targetJD: Double, targetDayStart: Date) -> (kMonthStart: Double, month: Int, isLeap: Bool, day: Int) {
        let comps = jstCalendar.dateComponents([.year, .month], from: targetDayStart)
        var k = lunationEstimateK(year: comps.year ?? 2000, month: comps.month ?? 1)

        while jstDayStart(ofJD: newMoonJD(k: k)) > targetDayStart { k -= 1 }
        while jstDayStart(ofJD: newMoonJD(k: k + 1)) <= targetDayStart { k += 1 }

        let monthStartDay = jstDayStart(ofJD: newMoonJD(k: k))
        let lunarDayCount = (jstCalendar.dateComponents([.day], from: monthStartDay, to: targetDayStart).day ?? 0) + 1

        // Find k11: the lunation containing the most recent Dec solstice.
        let candidateYear = (comps.month ?? 1) >= 11 ? (comps.year ?? 2000) : (comps.year ?? 2000) - 1
        guard let approxDec = jstCalendar.date(from: DateComponents(year: candidateYear, month: 12, day: 21, hour: 12)) else {
            return (k, 11, false, lunarDayCount)
        }
        let solsticeJD = findLongitudeCrossing(target: 270, near: julianDay(fromDate: approxDec))

        var k11 = lunationEstimateK(year: candidateYear, month: 12)
        while newMoonJD(k: k11) > solsticeJD { k11 -= 1 }
        while newMoonJD(k: k11 + 1) <= solsticeJD { k11 += 1 }

        var monthNumber = 11
        var isLeap = false
        var i = k11
        while i < k {
            i += 1
            if lunationContainsChuki(k: i) {
                monthNumber = monthNumber % 12 + 1
                isLeap = false
            } else {
                isLeap = true
            }
        }

        return (k, monthNumber, isLeap, lunarDayCount)
    }

    /// Whether a chūki (one of the 12 even solar terms, every 30°) falls on
    /// a civil day within this lunation. Must sample longitude at the JST
    /// civil-day boundaries rather than the precise new-moon instants —
    /// otherwise a chūki that lands on the same calendar day as the next
    /// new moon (which does happen) gets attributed to the wrong month.
    private static func lunationContainsChuki(k: Double) -> Bool {
        let startDay = jstDayStart(ofJD: newMoonJD(k: k))
        let endDay = jstDayStart(ofJD: newMoonJD(k: k + 1))
        let lonStart = solarLongitude(jd: julianDay(fromDate: startDay))
        let lonEnd = solarLongitude(jd: julianDay(fromDate: endDay))
        let sectorStart = Int(floor(lonStart / 30)) % 12
        let sectorEnd = Int(floor(lonEnd / 30)) % 12
        return sectorStart != sectorEnd
    }

    // MARK: - Rokuyō

    private static func rokuyo(month: Int, day: Int) -> String {
        let names = ["大安", "赤口", "先勝", "友引", "先負", "仏滅"]
        return names[((month + day) % 6 + 6) % 6]
    }

    // MARK: - Jūnichoku (twelve-day cycle tied to the current 節 solar term)

    /// The 12 "setsu" (odd solar terms) and the earthly branch each governs,
    /// in ecliptic-longitude order starting at risshun (315°).
    private static let setsuLongitudes: [Double] = [315, 345, 15, 45, 75, 105, 135, 165, 195, 225, 255, 285]
    private static let setsuBranchIndices = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1] // 寅卯辰巳午未申酉戌亥子丑
    private static let junichokuNames = ["建", "除", "満", "平", "定", "執", "破", "危", "成", "納", "開", "閉"]

    private static func junichoku(dayBranchIndex: Int, targetJD: Double) -> String {
        let lon = solarLongitude(jd: targetJD)
        // Which of the 12 setsu periods (each 30° wide, starting at 315°) are we in.
        let offset = norm360(lon - 315)
        let setsuIndex = Int(floor(offset / 30)) % 12
        let setsuBranch = setsuBranchIndices[setsuIndex]
        let idx = ((dayBranchIndex - setsuBranch) % 12 + 12) % 12
        return junichokuNames[idx]
    }

    // MARK: - Moon phase

    private static func moonPhase(lunarDay: Int) -> (name: String, symbol: String) {
        switch lunarDay {
        case 1: return ("新月", "moonphase.new.moon")
        case 2...5: return ("三日月", "moonphase.waxing.crescent")
        case 6...8: return ("上弦", "moonphase.first.quarter")
        case 9...13: return ("十三夜", "moonphase.waxing.gibbous")
        case 14...16: return ("満月", "moonphase.full.moon")
        case 17...21: return ("十六夜", "moonphase.waning.gibbous")
        case 22...24: return ("下弦", "moonphase.last.quarter")
        default: return ("有明", "moonphase.waning.crescent")
        }
    }
}
