import Foundation
import EventKit
import CoreLocation
import UIKit

// MARK: - Calendar Info Model
struct CalendarInfo: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let colorHex: String
    var isEnabled: Bool

    static func == (lhs: CalendarInfo, rhs: CalendarInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Calendar Event Model
struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let location: String?
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColor: CGColor?
    let calendarTitle: String
    let calendarId: String

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endDate)
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

// MARK: - Calendar Service
@MainActor
class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()
    private let selectedCalendarsKey = "selectedCalendarIds"

    @Published var isAuthorized: Bool = false
    @Published var todayEvents: [CalendarEvent] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [CalendarInfo] = []
    @Published var selectedCalendarIds: Set<String> = []

    init() {
        checkAuthorizationStatus()
        loadSelectedCalendars()
    }

    private func loadSelectedCalendars() {
        if let savedIds = UserDefaults.standard.array(forKey: selectedCalendarsKey) as? [String] {
            selectedCalendarIds = Set(savedIds)
        }
    }

    private func saveSelectedCalendars() {
        UserDefaults.standard.set(Array(selectedCalendarIds), forKey: selectedCalendarsKey)
    }

    func toggleCalendar(_ calendarId: String) {
        if selectedCalendarIds.contains(calendarId) {
            selectedCalendarIds.remove(calendarId)
        } else {
            selectedCalendarIds.insert(calendarId)
        }
        saveSelectedCalendars()

        // Update available calendars state
        if let index = availableCalendars.firstIndex(where: { $0.id == calendarId }) {
            availableCalendars[index].isEnabled = selectedCalendarIds.contains(calendarId)
        }
    }

    func fetchAvailableCalendars() {
        guard isAuthorized else { return }

        let calendars = eventStore.calendars(for: .event)

        // If no calendars selected yet, select all by default
        if selectedCalendarIds.isEmpty {
            selectedCalendarIds = Set(calendars.map { $0.calendarIdentifier })
            saveSelectedCalendars()
        }

        availableCalendars = calendars.map { cal in
            CalendarInfo(
                id: cal.calendarIdentifier,
                title: cal.title,
                colorHex: colorToHex(cal.cgColor),
                isEnabled: selectedCalendarIds.contains(cal.calendarIdentifier)
            )
        }.sorted { $0.title.lowercased() < $1.title.lowercased() }
    }

    private func colorToHex(_ cgColor: CGColor?) -> String {
        guard let cgColor = cgColor,
              let components = cgColor.components,
              components.count >= 3 else {
            return "#007AFF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private var selectedCalendars: [EKCalendar]? {
        guard isAuthorized, !selectedCalendarIds.isEmpty else { return nil }
        let allCalendars = eventStore.calendars(for: .event)
        let filtered = allCalendars.filter { selectedCalendarIds.contains($0.calendarIdentifier) }
        return filtered.isEmpty ? nil : filtered
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status
        isAuthorized = (status == .fullAccess || status == .authorized)
    }

    func requestAccess() async -> Bool {
        do {
            // iOS 17+ uses requestFullAccessToEvents
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    self.isAuthorized = granted
                    self.authorizationStatus = granted ? .fullAccess : .denied
                }
                return granted
            } else {
                // Fallback for older iOS versions
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    self.isAuthorized = granted
                    self.authorizationStatus = granted ? .authorized : .denied
                }
                return granted
            }
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    // MARK: - Fetch Events

    func fetchTodayEvents() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        fetchEvents(from: startOfDay, to: endOfDay)
    }

    func fetchEvents(for date: Date) {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        fetchEvents(from: startOfDay, to: endOfDay)
    }

    /// Fetch events for a specific day of the week
    /// - Parameter dayOfWeek: Calendar weekday value (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    /// - Parameter weekOffset: Number of weeks from current week (0 = this week, 1 = next week, -1 = last week)
    func fetchEventsForDay(_ dayOfWeek: Int, weekOffset: Int = 0) {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let today = Date()

        // Get the current weekday (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        let currentWeekday = calendar.component(.weekday, from: today)

        // Calculate days to add/subtract to get to target day
        var daysToAdd = dayOfWeek - currentWeekday

        // Apply week offset
        daysToAdd += weekOffset * 7

        guard let targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: today) else { return }

        let startOfDay = calendar.startOfDay(for: targetDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        fetchEvents(from: startOfDay, to: endOfDay)
    }

    private func fetchEvents(from startDate: Date, to endDate: Date) {
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
        let ekEvents = eventStore.events(matching: predicate)

        // Filter to only include timed events (not all-day events) and convert
        let timedEvents = ekEvents
            .filter { !$0.isAllDay } // Only events with specific times
            .map { event -> CalendarEvent in
                CalendarEvent(
                    id: event.eventIdentifier,
                    title: event.title ?? "Untitled",
                    location: event.location,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarColor: event.calendar.cgColor,
                    calendarTitle: event.calendar.title,
                    calendarId: event.calendar.calendarIdentifier
                )
            }
            .sorted { $0.startDate < $1.startDate }

        todayEvents = timedEvents
    }

    // MARK: - Helper Methods

    func refreshEvents() {
        checkAuthorizationStatus()
        if isAuthorized {
            fetchAvailableCalendars()
            fetchTodayEvents()
        }
    }

    // MARK: - Session Sync to Calendar

    /// Get or create the Keel calendar for syncing sessions
    func getKeelCalendar() -> EKCalendar? {
        guard isAuthorized else { return nil }

        // Look for existing Keel calendar
        let calendars = eventStore.calendars(for: .event)
        if let keelCalendar = calendars.first(where: { $0.title == "Keel Sessions" }) {
            return keelCalendar
        }

        // Create new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = "Keel Sessions"
        newCalendar.cgColor = UIColor.systemBlue.cgColor

        // Find a suitable source
        if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else if let icloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") }) {
            newCalendar.source = icloudSource
        } else if let firstSource = eventStore.sources.first {
            newCalendar.source = firstSource
        }

        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            print("Error creating Keel calendar: \(error)")
            return nil
        }
    }

    /// Sync a session to Apple Calendar
    func syncSession(
        name: String,
        room: String,
        locationName: String?,
        locationAddress: String?,
        startTime: Date,
        endTime: Date,
        dayOfWeek: Int,
        repeatWeekly: Bool,
        existingEventId: String? = nil
    ) -> String? {
        guard isAuthorized, let calendar = getKeelCalendar() else { return nil }

        let event: EKEvent
        if let eventId = existingEventId,
           let existing = eventStore.event(withIdentifier: eventId) {
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
        }

        event.calendar = calendar
        event.title = name
        event.location = [room, locationName, locationAddress]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        // Calculate the actual date for this session
        let actualDate = nextOccurrence(of: dayOfWeek, startTime: startTime, endTime: endTime)
        event.startDate = actualDate.start
        event.endDate = actualDate.end

        // Set up recurrence if repeating weekly
        if repeatWeekly {
            let recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
            event.recurrenceRules = [recurrenceRule]
        } else {
            event.recurrenceRules = nil
        }

        do {
            try eventStore.save(event, span: repeatWeekly ? .futureEvents : .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error saving event: \(error)")
            return nil
        }
    }

    /// Delete a synced session from Apple Calendar
    func deleteSession(eventId: String) {
        guard isAuthorized,
              let event = eventStore.event(withIdentifier: eventId) else { return }

        do {
            try eventStore.remove(event, span: .futureEvents)
        } catch {
            print("Error deleting event: \(error)")
        }
    }

    /// Find the next occurrence of a specific weekday
    /// - Parameter dayOfWeek: Calendar weekday value (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    private func nextOccurrence(of dayOfWeek: Int, startTime: Date, endTime: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = Date()

        // Get time components from the lesson times
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        // Get the current weekday (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        let currentWeekday = calendar.component(.weekday, from: today)

        // Calculate days until next occurrence of target weekday
        var daysToAdd = dayOfWeek - currentWeekday
        if daysToAdd < 0 {
            daysToAdd += 7 // Next week
        }

        guard let targetDay = calendar.date(byAdding: .day, value: daysToAdd, to: today) else {
            return (today, today)
        }

        // Build the start date with correct time
        var targetStartComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
        targetStartComponents.hour = startComponents.hour
        targetStartComponents.minute = startComponents.minute
        let targetStartDate = calendar.date(from: targetStartComponents) ?? today

        // Build the end date with correct time
        var targetEndComponents = calendar.dateComponents([.year, .month, .day], from: targetDay)
        targetEndComponents.hour = endComponents.hour
        targetEndComponents.minute = endComponents.minute
        let targetEndDate = calendar.date(from: targetEndComponents) ?? targetStartDate

        return (targetStartDate, targetEndDate)
    }
}
