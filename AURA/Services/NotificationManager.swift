import SwiftUI
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    // Deep link categories for Cinema
    static let movieLoggedCategory = "MOVIE_LOGGED"
    static let watchlistAddedCategory = "WATCHLIST_ADDED"
    static let lessonReadyCategory = "LESSON_READY"
    static let quizReminderCategory = "QUIZ_REMINDER"

    override init() {
        super.init()
    }

    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Define notification actions for Cinema
        let openLessonAction = UNNotificationAction(
            identifier: "OPEN_LESSON",
            title: "Открыть урок",
            options: [.foreground]
        )
        let quizAction = UNNotificationAction(
            identifier: "START_QUIZ",
            title: "Пройти квиз",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Позже",
            options: [.destructive]
        )

        // Movie logged — open lesson
        let movieLoggedCat = UNNotificationCategory(
            identifier: NotificationManager.movieLoggedCategory,
            actions: [openLessonAction, quizAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Watchlist added
        let watchlistCat = UNNotificationCategory(
            identifier: NotificationManager.watchlistAddedCategory,
            actions: [dismissAction],
            intentIdentifiers: [],
            options: []
        )

        // Lesson ready — words analyzed
        let lessonReadyCat = UNNotificationCategory(
            identifier: NotificationManager.lessonReadyCategory,
            actions: [openLessonAction, quizAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Quiz reminder
        let quizCat = UNNotificationCategory(
            identifier: NotificationManager.quizReminderCategory,
            actions: [quizAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([movieLoggedCat, watchlistCat, lessonReadyCat, quizCat])

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted { print("Notifications granted") }
        }
    }

    // MARK: - Cinema Notifications

    func sendMovieLoggedNotification(movieTitle: String, tmdbId: Int? = nil) {
        guard ProfileSettings.shared.notifWatchedEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "🎬 \(movieTitle) залогирован!"
        content.body = "Слова, факты и квиз уже готовы — открой урок"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.movieLoggedCategory
        if let id = tmdbId {
            content.userInfo = ["tmdbId": id, "movieTitle": movieTitle, "deepLink": "cinema://watched"]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "movie_logged_\(UUID().uuidString)",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendWatchlistNotification(movieTitle: String, tmdbId: Int? = nil) {
        guard ProfileSettings.shared.notifWatchlistEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "🔖 \(movieTitle) в Watchlist"
        content.body = "Добавлено в список — посмотри когда будет настроение"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.watchlistAddedCategory
        if let id = tmdbId {
            content.userInfo = ["tmdbId": id, "movieTitle": movieTitle, "deepLink": "cinema://watchlist"]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "watchlist_\(UUID().uuidString)",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func sendLessonReadyNotification(movieTitle: String, wordCount: Int, tmdbId: Int? = nil) {
        guard ProfileSettings.shared.notifLessonEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "📚 Урок по «\(movieTitle)» готов!"
        content.body = "\(wordCount) новых слов + словарь персонажей ждут тебя"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.lessonReadyCategory
        if let id = tmdbId {
            content.userInfo = ["tmdbId": id, "movieTitle": movieTitle, "deepLink": "cinema://lesson"]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "lesson_ready_\(UUID().uuidString)",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleQuizReminder() {
        guard ProfileSettings.shared.notifQuizEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "🧠 Время для кино-квиза!"
        content.body = "Повтори слова из посмотренных фильмов — 5 минут для прогресса"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.quizReminderCategory
        content.userInfo = ["deepLink": "cinema://quiz"]

        var components = DateComponents()
        components.hour = 19
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "cinema_quiz_reminder",
            content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Existing Notifications

    func scheduleDinnerReminder() {
        guard ProfileSettings.shared.notifFoodEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "🍽️ Время ужина!"
        content.body = "Ты ещё не залогировал ужин. Посмотри что рекомендует AURA на сегодня."
        content.sound = .default

        var components = DateComponents()
        components.hour = 18
        components.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dinner_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendWordStreakNotification(streak: Int) {
        guard ProfileSettings.shared.notifStreakEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak \(streak) дней!"
        content.body = "Не забудь выучить слова сегодня чтобы не потерять streak"
        content.sound = .default
        content.badge = 1

        var components = DateComponents()
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "streak_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func sendCalorieReminderNotification(remaining: Int) {
        guard ProfileSettings.shared.notifFoodEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "⚡ Осталось \(remaining) ккал"
        content.body = "Не забудь добавить ужин в дневник питания"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "calorie_reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let deepLink = userInfo["deepLink"] as? String ?? ""

        // Post notification for the app to handle deep linking
        NotificationCenter.default.post(
            name: Notification.Name("CinemaDeepLink"),
            object: nil,
            userInfo: ["deepLink": deepLink, "action": response.actionIdentifier]
        )

        completionHandler()
    }
}
