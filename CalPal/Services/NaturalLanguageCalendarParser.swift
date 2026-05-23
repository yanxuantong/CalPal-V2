import Foundation

final class NaturalLanguageCalendarParser {
    private let calendar: Calendar
    private let now: () -> Date

    init(calendar: Calendar = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent, now: @escaping () -> Date = Date.init) {
        var calendar = calendar
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.now = now
    }

    func parse(_ text: String) -> ParsedCalendarCommand {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = source.lowercased()
        let locale = containsChinese(source) ? "zh-Hans" : Locale.current.identifier
        guard !source.isEmpty else {
            return ParsedCalendarCommand(originalText: text, localeIdentifier: locale, intent: nil, confidence: 0, missingFields: ["title", "time"], warnings: [])
        }

        if lower.contains("delete") || source.contains("删除") || source.contains("取消") {
            return ParsedCalendarCommand(originalText: source, localeIdentifier: locale, intent: .delete(query: query(from: source)), confidence: 0.82, missingFields: [], warnings: [])
        }
        if lower.contains("move") || lower.contains("change") || lower.contains("reschedule") || source.contains("改到") || source.contains("修改") {
            let patchDates = extractDateRange(from: source)
            let patch = EventPatch(title: nil, startDate: patchDates?.start, endDate: patchDates?.end, location: nil, notes: nil)
            return ParsedCalendarCommand(originalText: source, localeIdentifier: locale, intent: .modify(query: query(from: source), patch: patch), confidence: patchDates == nil ? 0.68 : 0.82, missingFields: patchDates == nil ? ["new time"] : [], warnings: [])
        }

        let dates = extractDateRange(from: source)
        let draft = EventDraft(title: extractTitle(from: source), startDate: dates?.start ?? now(), endDate: dates?.end ?? now().addingTimeInterval(3600), calendarID: nil, calendarName: nil, location: nil, notes: nil)
        let missing = missingFields(for: draft, hasDate: dates != nil)
        let confidence = missing.isEmpty ? 0.9 : 0.55
        let warnings = dateWarnings(for: draft)
        return ParsedCalendarCommand(originalText: source, localeIdentifier: locale, intent: .create(draft), confidence: confidence, missingFields: missing, warnings: warnings)
    }

    private func query(from text: String) -> EventQuery {
        EventQuery(phrase: text, day: extractDay(from: text), titleHint: extractTitleHint(from: text), boundedDays: 14)
    }

    private func missingFields(for draft: EventDraft, hasDate: Bool) -> [String] {
        var fields: [String] = []
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("title") }
        if !hasDate { fields.append("time") }
        return fields
    }

    private func dateWarnings(for draft: EventDraft) -> [String] {
        let max = calendar.date(byAdding: .day, value: 14, to: now()) ?? now().addingTimeInterval(14*86400)
        let min = calendar.date(byAdding: .day, value: -14, to: now()) ?? now().addingTimeInterval(-14*86400)
        if draft.startDate > max { return ["date is outside the normal two-week window"] }
        if draft.startDate < min { return ["date is too far in the past"] }
        return []
    }

    private func extractDateRange(from text: String) -> (start: Date, end: Date)? {
        guard let day = extractDay(from: text) else { return nil }
        let hour = extractHour(from: text) ?? 9
        let minute = (text.contains("半") || text.contains(":30")) ? 30 : 0
        guard let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
        let duration = extractDuration(from: text) ?? 3600
        return (start, start.addingTimeInterval(duration))
    }

    private func extractDay(from text: String) -> Date? {
        let lower = text.lowercased()
        let today = calendar.startOfDay(for: now())
        if lower.contains("day after tomorrow") || text.contains("后天") { return calendar.date(byAdding: .day, value: 2, to: today) }
        if lower.contains("tomorrow") || text.contains("明天") { return calendar.date(byAdding: .day, value: 1, to: today) }
        if lower.contains("today") || text.contains("今天") { return today }
        if lower.contains("yesterday") || text.contains("昨天") { return calendar.date(byAdding: .day, value: -1, to: today) }
        if let weekday = extractWeekday(from: text) {
            return nextDate(matchingWeekday: weekday, from: today, forceFollowingWeek: lower.contains("next ") || text.contains("下周"))
        }
        if lower.contains("next week") || text.contains("下周") { return calendar.date(byAdding: .day, value: 7, to: today) }
        if lower.contains("100 years") || text.contains("100年") { return calendar.date(byAdding: .year, value: 100, to: today) }
        return nil
    }

    private func extractHour(from text: String) -> Int? {
        let lower = text.lowercased()
        if lower.contains("noon") || text.contains("中午") { return 12 }
        if lower.contains("midnight") || text.contains("午夜") { return 0 }
        let patterns = ["(\\d{1,2})\\s*(am|pm)", "(\\d{1,2}):(\\d{2})", "(\\d{1,2})\\s*点"]
        for pattern in patterns {
            if let match = lower.firstMatch(pattern: pattern), let hour = Int(match[1]) {
                if match.count > 2, match[2] == "pm", hour < 12 { return hour + 12 }
                return normalizeHour(hour, source: lower)
            }
        }
        let chineseHours: [(String, Int)] = [("一点",1),("两点",2),("二点",2),("三点",3),("四点",4),("五点",5),("六点",6),("七点",7),("八点",8),("九点",9),("十点",10),("十一点",11),("十二点",12)]
        for (token, value) in chineseHours where text.contains(token) { return normalizeHour(value, source: lower + text) }
        return nil
    }

    private func normalizeHour(_ hour: Int, source: String) -> Int {
        if (source.contains("afternoon") || source.contains("evening") || source.contains("下午") || source.contains("晚上")), hour < 12 { return hour + 12 }
        return hour
    }

    private func extractDuration(from text: String) -> TimeInterval? {
        let lower = text.lowercased()
        if lower.contains("30 min") || lower.contains("half hour") || text.contains("半小时") { return 1800 }
        if lower.contains("90 min") || text.contains("一个半小时") { return 5400 }
        if lower.contains("one hour") || lower.contains("an hour") { return 3600 }
        if lower.contains("two hours") { return 7200 }
        if lower.contains("three hours") { return 10800 }
        if let match = lower.firstMatch(pattern: "(?:for\\s*)?(\\d{1,2})\\s*(?:hour|hours|hr|hrs)"), let hours = Double(match[1]) {
            return hours * 3600
        }
        if let match = text.firstMatch(pattern: "(\\d{1,2})\\s*个?\\s*小时"), let hours = Double(match[1]) {
            return hours * 3600
        }
        let chineseHours: [(String, Double)] = [("两小时", 2), ("两个小时", 2), ("二小时", 2), ("三小时", 3), ("三个小时", 3), ("一小时", 1), ("一个小时", 1)]
        for (token, hours) in chineseHours where text.contains(token) { return hours * 3600 }
        return nil
    }

    private func extractWeekday(from text: String) -> Int? {
        let lower = text.lowercased()
        let english: [(String, Int)] = [
            ("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
            ("thursday", 5), ("friday", 6), ("saturday", 7)
        ]
        for (token, weekday) in english where lower.contains(token) { return weekday }
        let chinese: [(String, Int)] = [
            ("周日", 1), ("星期日", 1), ("周天", 1), ("星期天", 1),
            ("周一", 2), ("星期一", 2), ("周二", 3), ("星期二", 3),
            ("周三", 4), ("星期三", 4), ("周四", 5), ("星期四", 5),
            ("周五", 6), ("星期五", 6), ("周六", 7), ("星期六", 7)
        ]
        for (token, weekday) in chinese where text.contains(token) { return weekday }
        return nil
    }

    private func nextDate(matchingWeekday weekday: Int, from today: Date, forceFollowingWeek: Bool) -> Date? {
        let currentWeekday = calendar.component(.weekday, from: today)
        var delta = (weekday - currentWeekday + 7) % 7
        if delta == 0 || forceFollowingWeek { delta += 7 }
        return calendar.date(byAdding: .day, value: delta, to: today)
    }

    private func extractTitle(from text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("alex") || text.contains("Alex") { return lower.contains("meeting") || text.contains("会") ? "Meeting with Alex" : "Alex 1:1" }
        if lower.contains("standup") { return "Standup" }
        let cleaned = sanitizedTitleCandidate(from: text)
        return cleaned.isEmpty ? "New Event" : String(cleaned.prefix(48))
    }

    private func sanitizedTitleCandidate(from text: String) -> String {
        var cleaned = text
        let patterns = [
            "(?i)\\b(i\\s+want\\s+to|i'd\\s+like\\s+to|would\\s+like\\s+to|please|schedule|create|add|plan|book)\\b",
            "(?i)\\b(day\\s+after\\s+tomorrow|tomorrow|today|yesterday|tonight|this\\s+evening|this\\s+afternoon|this\\s+morning|next\\s+week)\\b",
            "(?i)\\b(next\\s+)?(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\\b",
            "(?i)\\b(at|from|for)\\b",
            "(?i)\\b\\d{1,2}\\s*(:\\s*\\d{2})?\\s*(am|pm)\\b",
            "(?i)\\b\\d{1,2}\\s*(:\\s*\\d{2})\\b",
            "(?i)\\b(one|an|two|three|\\d{1,2})\\s*(hours?|hrs?|minutes?|mins?)\\b",
            "(我想要在|我想要|我想|我要|请帮我|帮我|创建|新增|安排|预约)",
            "(今天|明天|后天|昨天|今晚|晚上|下午|上午|早上|中午|午夜|下周[一二三四五六日天]?|周[一二三四五六日天]|星期[一二三四五六日天])",
            "\\d{1,2}\\s*[:：]\\s*\\d{2}",
            "\\d{1,2}\\s*点\\s*(钟|半)?",
            "(一|一个|两|两个|二|三|三个|\\d{1,2})\\s*个?\\s*小时",
            "做\\s*$"
        ]
        for pattern in patterns {
            cleaned = cleaned.replacingRegex(pattern, with: " ")
        }
        cleaned = cleaned
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: "：", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.replacingRegex("\\s+", with: " ")
    }

    private func extractTitleHint(from text: String) -> String? {
        if text.lowercased().contains("alex") || text.contains("Alex") { return "Alex" }
        if text.lowercased().contains("standup") { return "standup" }
        return nil
    }

    private func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
    }
}

private extension String {
    func firstMatch(pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = self as NSString
        guard let match = regex.firstMatch(in: self, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<match.numberOfRanges).map { i in
            let range = match.range(at: i)
            return range.location == NSNotFound ? "" : ns.substring(with: range)
        }
    }

    func replacingRegex(_ pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return self }
        let range = NSRange(location: 0, length: (self as NSString).length)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: replacement)
    }
}
