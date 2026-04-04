import WidgetKit
import SwiftUI

@main
struct KeelWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity
        LessonLiveActivity()

        // Home Screen Widgets
        NextClassWidget()
        TodayScheduleWidget()
        CountdownWidget()
        ClassProgressWidget()

        // Lock Screen Widgets
        LockScreenNextClassWidget()
        LockScreenScheduleWidget()

        // Control Center Widgets (iOS 18+)
        if #available(iOS 18.0, *) {
            NextClassControl()
            ClassCountControl()
            StudyTimerControl()
            QuickScheduleControl()
        }
    }
}
