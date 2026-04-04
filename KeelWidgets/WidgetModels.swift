import SwiftUI

// MARK: - Shared Widget Data Models
// These models are shared across all widgets for decoding data from the main app

struct WidgetClassData: Codable {
    let name: String
    let room: String
    let startTime: Date
    let endTime: Date
    let colorHex: String
    let iconName: String
}

struct ScheduleWidgetClass: Codable, Identifiable {
    var id: String { name + startTime }
    let name: String
    let room: String
    let startTime: String
    let endTime: String
    let colorHex: String
    let iconName: String
    let isActive: Bool
}

// Color.fromHex is defined in LessonActivityAttributes.swift
