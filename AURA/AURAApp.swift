import SwiftUI
import BackgroundTasks

@main
struct AURAApp: App {

    init() {
        // Настраиваем уведомления (запрос разрешений + категории)
        NotificationManager.shared.requestPermission()
        // Регистрируем фоновую задачу для синка Letterboxd
        LetterboxdSyncService.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Планируем следующий фоновый синк
                    LetterboxdSyncService.scheduleBackgroundSync()
                }
        }
    }
}
