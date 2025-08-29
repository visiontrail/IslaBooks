import Foundation

extension Date {
    
    // MARK: - Formatting
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
    
    func formattedRelative() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
    
    func formattedDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: self)
    }
    
    // MARK: - ISO 8601
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
    
    static func from(iso8601String: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso8601String)
    }
    
    // MARK: - Components
    var year: Int {
        return Calendar.current.component(.year, from: self)
    }
    
    var month: Int {
        return Calendar.current.component(.month, from: self)
    }
    
    var day: Int {
        return Calendar.current.component(.day, from: self)
    }
    
    var hour: Int {
        return Calendar.current.component(.hour, from: self)
    }
    
    var minute: Int {
        return Calendar.current.component(.minute, from: self)
    }
    
    var weekday: Int {
        return Calendar.current.component(.weekday, from: self)
    }
    
    // MARK: - Calculations
    func adding(_ component: Calendar.Component, value: Int) -> Date {
        return Calendar.current.date(byAdding: component, value: value, to: self) ?? self
    }
    
    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    func endOfDay() -> Date {
        let startOfDay = self.startOfDay()
        return startOfDay.adding(.day, value: 1).addingTimeInterval(-1)
    }
    
    func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    func startOfYear() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }
    
    // MARK: - Comparisons
    func isSameDay(as date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isSameWeek(as date: Date) -> Bool {
        return Calendar.current.isDate(self, equalTo: date, toGranularity: .weekOfYear)
    }
    
    func isSameMonth(as date: Date) -> Bool {
        return Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }
    
    func isSameYear(as date: Date) -> Bool {
        return Calendar.current.isDate(self, equalTo: date, toGranularity: .year)
    }
    
    func isToday() -> Bool {
        return isSameDay(as: Date())
    }
    
    func isYesterday() -> Bool {
        return isSameDay(as: Date().adding(.day, value: -1))
    }
    
    func isTomorrow() -> Bool {
        return isSameDay(as: Date().adding(.day, value: 1))
    }
    
    func isThisWeek() -> Bool {
        return isSameWeek(as: Date())
    }
    
    func isThisMonth() -> Bool {
        return isSameMonth(as: Date())
    }
    
    func isThisYear() -> Bool {
        return isSameYear(as: Date())
    }
    
    // MARK: - Age/Duration
    func timeIntervalUntilNow() -> TimeInterval {
        return Date().timeIntervalSince(self)
    }
    
    func daysUntilNow() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: Date())
        return components.day ?? 0
    }
    
    func weeksUntilNow() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: self, to: Date())
        return components.weekOfYear ?? 0
    }
    
    func monthsUntilNow() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: self, to: Date())
        return components.month ?? 0
    }
    
    func yearsUntilNow() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self, to: Date())
        return components.year ?? 0
    }
}

// MARK: - TimeInterval Extensions
extension TimeInterval {
    
    // MARK: - Formatting
    func formattedDuration() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formattedReadingTime() -> String {
        let totalMinutes = Int(self / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)小时\(minutes)分钟"
            } else {
                return "\(hours)小时"
            }
        } else {
            return "\(minutes)分钟"
        }
    }
    
    // MARK: - Convenience Constructors
    static func seconds(_ value: Double) -> TimeInterval {
        return value
    }
    
    static func minutes(_ value: Double) -> TimeInterval {
        return value * 60
    }
    
    static func hours(_ value: Double) -> TimeInterval {
        return value * 3600
    }
    
    static func days(_ value: Double) -> TimeInterval {
        return value * 86400
    }
    
    static func weeks(_ value: Double) -> TimeInterval {
        return value * 604800
    }
    
    // MARK: - Getters
    var seconds: Double {
        return self
    }
    
    var minutes: Double {
        return self / 60
    }
    
    var hours: Double {
        return self / 3600
    }
    
    var days: Double {
        return self / 86400
    }
    
    var weeks: Double {
        return self / 604800
    }
}

