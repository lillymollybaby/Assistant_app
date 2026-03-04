import SwiftUI
import Combine

// MARK: - ProfileSettings
class ProfileSettings: ObservableObject {
    static let shared = ProfileSettings()

    @Published var city: String            { didSet { save("city", city); syncToServer() } }
    @Published var learningLanguage: String { didSet { save("learning_language", learningLanguage); syncToServer() } }
    @Published var letterboxdUsername: String { didSet { save("letterboxd_username", letterboxdUsername); syncToServer() } }
    @Published var calorieGoal: Int        { didSet { UserDefaults.standard.set(calorieGoal, forKey: "calorie_goal_local"); syncToServer() } }
    @Published var darkMode: String        { didSet { save("dark_mode", darkMode); syncToServer() } }
    @Published var gatheringTime: Int      { didSet { UserDefaults.standard.set(gatheringTime, forKey: "gathering_time"); syncToServer() } }
    @Published var wordsDailyGoal: Int     { didSet { UserDefaults.standard.set(wordsDailyGoal, forKey: "words_daily_goal"); syncToServer() } }
    @Published var hapticEnabled: Bool     { didSet { UserDefaults.standard.set(hapticEnabled, forKey: "haptic_on"); syncToServer() } }
    @Published var aiPersonality: String   { didSet { save("ai_personality", aiPersonality); syncToServer() } }
    @Published var units: String           { didSet { save("units", units); syncToServer() } }
    @Published var weekStart: String       { didSet { save("week_start", weekStart); syncToServer() } }

    // Notification toggles — per category
    @Published var notifWatchedEnabled: Bool     { didSet { UserDefaults.standard.set(notifWatchedEnabled, forKey: "notif_watched"); syncToServer() } }
    @Published var notifWatchlistEnabled: Bool   { didSet { UserDefaults.standard.set(notifWatchlistEnabled, forKey: "notif_watchlist"); syncToServer() } }
    @Published var notifLessonEnabled: Bool      { didSet { UserDefaults.standard.set(notifLessonEnabled, forKey: "notif_lesson"); syncToServer() } }
    @Published var notifFoodEnabled: Bool        { didSet { UserDefaults.standard.set(notifFoodEnabled, forKey: "notif_food"); syncToServer() } }
    @Published var notifRouteEnabled: Bool       { didSet { UserDefaults.standard.set(notifRouteEnabled, forKey: "notif_route"); syncToServer() } }
    @Published var notifQuizEnabled: Bool        { didSet { UserDefaults.standard.set(notifQuizEnabled, forKey: "notif_quiz"); syncToServer() } }
    @Published var notifStreakEnabled: Bool       { didSet { UserDefaults.standard.set(notifStreakEnabled, forKey: "notif_streak"); syncToServer() } }

    private var isSyncing = false
    private var syncDebounceTask: Task<Void, Never>?

    private func save(_ key: String, _ value: String) { UserDefaults.standard.set(value, forKey: key) }

    init() {
        city             = UserDefaults.standard.string(forKey: "city") ?? ""
        learningLanguage = UserDefaults.standard.string(forKey: "learning_language") ?? "German"
        letterboxdUsername = UserDefaults.standard.string(forKey: "letterboxd_username") ?? ""
        let cal = UserDefaults.standard.integer(forKey: "calorie_goal_local")
        calorieGoal      = cal == 0 ? 2200 : cal
        darkMode         = UserDefaults.standard.string(forKey: "dark_mode") ?? "Системная"
        let gt = UserDefaults.standard.integer(forKey: "gathering_time")
        gatheringTime    = gt == 0 ? 15 : gt
        let wd = UserDefaults.standard.integer(forKey: "words_daily_goal")
        wordsDailyGoal   = wd == 0 ? 10 : wd
        hapticEnabled    = UserDefaults.standard.object(forKey: "haptic_on") as? Bool ?? true
        aiPersonality    = UserDefaults.standard.string(forKey: "ai_personality") ?? "Balanced"
        units            = UserDefaults.standard.string(forKey: "units") ?? "Metric"
        weekStart        = UserDefaults.standard.string(forKey: "week_start") ?? "Monday"

        notifWatchedEnabled   = UserDefaults.standard.object(forKey: "notif_watched") as? Bool ?? true
        notifWatchlistEnabled = UserDefaults.standard.object(forKey: "notif_watchlist") as? Bool ?? true
        notifLessonEnabled    = UserDefaults.standard.object(forKey: "notif_lesson") as? Bool ?? true
        notifFoodEnabled      = UserDefaults.standard.object(forKey: "notif_food") as? Bool ?? true
        notifRouteEnabled     = UserDefaults.standard.object(forKey: "notif_route") as? Bool ?? true
        notifQuizEnabled      = UserDefaults.standard.object(forKey: "notif_quiz") as? Bool ?? true
        notifStreakEnabled    = UserDefaults.standard.object(forKey: "notif_streak") as? Bool ?? true
    }

    /// Convert all settings to a dictionary for server sync
    func toDictionary() -> [String: Any] {
        return [
            "city": city,
            "learning_language": learningLanguage,
            "letterboxd_username": letterboxdUsername,
            "calorie_goal": calorieGoal,
            "dark_mode": darkMode,
            "gathering_time": gatheringTime,
            "words_daily_goal": wordsDailyGoal,
            "haptic_enabled": hapticEnabled,
            "ai_personality": aiPersonality,
            "units": units,
            "week_start": weekStart,
            "notif_watched": notifWatchedEnabled,
            "notif_watchlist": notifWatchlistEnabled,
            "notif_lesson": notifLessonEnabled,
            "notif_food": notifFoodEnabled,
            "notif_route": notifRouteEnabled,
            "notif_quiz": notifQuizEnabled,
            "notif_streak": notifStreakEnabled,
        ]
    }

    /// Apply preferences from server response
    func applyFromServer(_ prefs: [String: AnyCodableValue]) {
        isSyncing = true
        defer { isSyncing = false }

        if let v = prefs["city"]?.stringValue { city = v; save("city", v) }
        if let v = prefs["learning_language"]?.stringValue { learningLanguage = v; save("learning_language", v) }
        if let v = prefs["letterboxd_username"]?.stringValue { letterboxdUsername = v; save("letterboxd_username", v) }
        if let v = prefs["calorie_goal"]?.intValue { calorieGoal = v; UserDefaults.standard.set(v, forKey: "calorie_goal_local") }
        if let v = prefs["dark_mode"]?.stringValue { darkMode = v; save("dark_mode", v) }
        if let v = prefs["gathering_time"]?.intValue { gatheringTime = v; UserDefaults.standard.set(v, forKey: "gathering_time") }
        if let v = prefs["words_daily_goal"]?.intValue { wordsDailyGoal = v; UserDefaults.standard.set(v, forKey: "words_daily_goal") }
        if let v = prefs["haptic_enabled"]?.boolValue { hapticEnabled = v; UserDefaults.standard.set(v, forKey: "haptic_on") }
        if let v = prefs["ai_personality"]?.stringValue { aiPersonality = v; save("ai_personality", v) }
        if let v = prefs["units"]?.stringValue { units = v; save("units", v) }
        if let v = prefs["week_start"]?.stringValue { weekStart = v; save("week_start", v) }
        if let v = prefs["notif_watched"]?.boolValue { notifWatchedEnabled = v; UserDefaults.standard.set(v, forKey: "notif_watched") }
        if let v = prefs["notif_watchlist"]?.boolValue { notifWatchlistEnabled = v; UserDefaults.standard.set(v, forKey: "notif_watchlist") }
        if let v = prefs["notif_lesson"]?.boolValue { notifLessonEnabled = v; UserDefaults.standard.set(v, forKey: "notif_lesson") }
        if let v = prefs["notif_food"]?.boolValue { notifFoodEnabled = v; UserDefaults.standard.set(v, forKey: "notif_food") }
        if let v = prefs["notif_route"]?.boolValue { notifRouteEnabled = v; UserDefaults.standard.set(v, forKey: "notif_route") }
        if let v = prefs["notif_quiz"]?.boolValue { notifQuizEnabled = v; UserDefaults.standard.set(v, forKey: "notif_quiz") }
        if let v = prefs["notif_streak"]?.boolValue { notifStreakEnabled = v; UserDefaults.standard.set(v, forKey: "notif_streak") }
    }

    /// Debounced sync to server (wait 1s after last change)
    func syncToServer() {
        guard !isSyncing else { return }
        guard AuthStorage.shared.isLoggedIn else { return }

        syncDebounceTask?.cancel()
        syncDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second debounce
            guard !Task.isCancelled else { return }
            let prefs = await MainActor.run { self.toDictionary() }
            let _ = try? await NetworkManager.shared.savePreferences(prefs)
        }
    }

    /// Load preferences from server (call on app launch / login)
    func loadFromServer() {
        Task {
            guard let response = try? await NetworkManager.shared.getPreferences() else { return }
            await MainActor.run {
                self.applyFromServer(response.preferences)
            }
        }
    }
}

// MARK: - ProfileView
struct ProfileView: View {
    @StateObject private var settings = ProfileSettings.shared
    @State private var user: UserResponse?
    @State private var streak: StreakResponse?
    @State private var myMovies: [MovieResponse] = []
    @State private var meals: [MealResponse] = []
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showChangePassword = false
    @State private var showEditName = false
    @State private var editedName = ""

    var watchedCount: Int { myMovies.filter { $0.watched == true }.count }
    var watchlistCount: Int { myMovies.filter { $0.watched == false }.count }
    var wordsLearned: Int { streak?.learned_words ?? 0 }
    var totalWords: Int { streak?.total_words ?? 0 }
    var streakDays: Int { streak?.streak_days ?? 0 }

    var initials: String {
        let n = user?.full_name ?? user?.email ?? "U"
        let parts = n.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(n.prefix(2)).uppercased()
    }

    var memberSince: String {
        guard let d = user?.created_at else { return "2024" }
        return String(d.prefix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    profileHeader
                        .padding(.top, 8)

                    quickStats

                    VStack(spacing: 2) {
                        sectionLabel("Настройки")
                        settingsMenu
                    }

                    VStack(spacing: 2) {
                        sectionLabel("Ещё")
                        aboutMenu
                    }

                    logoutButton
                        .padding(.top, 8)

                    Text("AURA v1.0.0")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
            .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
                Button("Выйти", role: .destructive) {
                    Task {
                        // Server-side logout (blacklist token)
                        let _ = try? await NetworkManager.shared.logout()
                    }
                    AuthStorage.shared.logout()
                    NotificationCenter.default.post(name: .didLogout, object: nil)
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Вы вернётесь на экран входа")
            }
            .alert("Удалить аккаунт?", isPresented: $showDeleteAccountAlert) {
                Button("Удалить навсегда", role: .destructive) {
                    Task {
                        let _ = try? await NetworkManager.shared.deleteAccount()
                        await MainActor.run {
                            AuthStorage.shared.logout()
                            NotificationCenter.default.post(name: .didLogout, object: nil)
                        }
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все ваши данные будут удалены безвозвратно. Это действие нельзя отменить.")
            }
            .sheet(isPresented: $showEditName) { editNameSheet }
            .sheet(isPresented: $showChangePassword) { ChangePasswordSheet() }
            .task { await loadData() }
        }
    }

    // MARK: - Profile Header
    var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple.opacity(0.8)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: .blue.opacity(0.25), radius: 16, y: 6)

                Text(initials)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(user?.full_name ?? "Пользователь")
                        .font(.title2.bold())
                    Button { showEditName = true } label: {
                        Image(systemName: "pencil.line")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let email = user?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("С \(memberSince) года")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Quick Stats
    var quickStats: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            QuickStatCard(icon: "flame.fill", iconColor: .orange,
                          value: "\(streakDays)", label: "дней подряд")
            QuickStatCard(icon: "film.fill", iconColor: .purple,
                          value: "\(watchedCount)", label: "фильмов")
            QuickStatCard(icon: "character.book.closed.fill", iconColor: .blue,
                          value: "\(wordsLearned)", label: "слов выучено")
            QuickStatCard(icon: "fork.knife", iconColor: .green,
                          value: "\(meals.count)", label: "приёмов пищи")
        }
    }

    // MARK: - Settings Menu
    var settingsMenu: some View {
        VStack(spacing: 0) {
            NavigationLink { CinemaSettingsPage() } label: {
                ProfileMenuRow(icon: "film.fill", iconColor: .purple,
                               title: "Кино", subtitle: platformsSummary)
            }
            menuDivider
            NavigationLink { LanguageSettingsPage() } label: {
                let lang = LanguageConfig.find(settings.learningLanguage)
                ProfileMenuRow(icon: "character.book.closed.fill", iconColor: .blue,
                               title: "Языки", subtitle: "\(lang.flag) \(lang.name) · \(settings.wordsDailyGoal) слов/день")
            }
            menuDivider
            NavigationLink { FoodSettingsPage() } label: {
                ProfileMenuRow(icon: "fork.knife", iconColor: .green,
                               title: "Питание", subtitle: "\(settings.calorieGoal) ккал")
            }
            menuDivider
            NavigationLink { RouteSettingsPage() } label: {
                ProfileMenuRow(icon: "location.fill", iconColor: .orange,
                               title: "Маршруты", subtitle: settings.city.isEmpty ? "Город не указан" : settings.city)
            }
            menuDivider
            NavigationLink { NotificationSettingsPage() } label: {
                ProfileMenuRow(icon: "bell.fill", iconColor: .red,
                               title: "Уведомления", subtitle: notifSummary)
            }
            menuDivider
            NavigationLink { AppearanceSettingsPage() } label: {
                ProfileMenuRow(icon: "paintbrush.fill", iconColor: .indigo,
                               title: "Оформление", subtitle: settings.darkMode)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    var menuDivider: some View {
        Divider().padding(.leading, 56)
    }

    var platformsSummary: String {
        let s = CinemaStorage.shared
        var p: [String] = []
        if !s.letterboxdUsername.isEmpty { p.append("Letterboxd") }
        if s.kinopoiskConnected { p.append("Кинопоиск") }
        if s.imdbConnected { p.append("IMDB") }
        return p.isEmpty ? "Нет платформ" : p.joined(separator: " · ")
    }

    var notifSummary: String {
        let all = [settings.notifWatchedEnabled, settings.notifWatchlistEnabled,
                   settings.notifLessonEnabled, settings.notifFoodEnabled,
                   settings.notifRouteEnabled, settings.notifQuizEnabled,
                   settings.notifStreakEnabled]
        let on = all.filter { $0 }.count
        if on == all.count { return "Все включены" }
        if on == 0 { return "Все выключены" }
        return "\(on) из \(all.count) включены"
    }

    // MARK: - About Menu
    var aboutMenu: some View {
        VStack(spacing: 0) {
            Button { showChangePassword = true } label: {
                ProfileMenuRow(icon: "key.fill", iconColor: .blue,
                               title: "Сменить пароль", subtitle: nil)
            }
            menuDivider
            NavigationLink { AboutAppPage() } label: {
                ProfileMenuRow(icon: "info.circle.fill", iconColor: .gray,
                               title: "О приложении", subtitle: "v1.0.0")
            }
            menuDivider
            NavigationLink { PrivacyPage() } label: {
                ProfileMenuRow(icon: "lock.shield.fill", iconColor: .gray,
                               title: "Конфиденциальность", subtitle: nil)
            }
            menuDivider
            Button { showDeleteAccountAlert = true } label: {
                ProfileMenuRow(icon: "trash.fill", iconColor: .red,
                               title: "Удалить аккаунт", subtitle: nil)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Logout Button
    var logoutButton: some View {
        Button {
            if settings.hapticEnabled { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            showLogoutAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                Text("Выйти из аккаунта")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Edit Name Sheet
    var editNameSheet: some View {
        NavigationStack {
            Form {
                Section("Отображаемое имя") {
                    TextField("Имя и фамилия", text: $editedName)
                }
                Section {
                    Text("Это имя будет видно только вам")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { showEditName = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { showEditName = false }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { editedName = user?.full_name ?? "" }
        }
    }

    func sectionLabel(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    func loadData() async {
        if let u = try? await NetworkManager.shared.getMe() { user = u }
        if let s: StreakResponse = try? await NetworkManager.shared.request("/languages/streak") { streak = s }
        if let m = try? await NetworkManager.shared.getMyMovies() { myMovies = m }
        if let ml = try? await NetworkManager.shared.getMealHistory() { meals = ml }
        // Sync preferences from server
        settings.loadFromServer()
    }
}

// MARK: - Quick Stat Card
struct QuickStatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Profile Menu Row
struct ProfileMenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Cinema Settings Page
struct CinemaSettingsPage: View {
    @ObservedObject var settings = ProfileSettings.shared
    @StateObject private var storage = CinemaStorage.shared
    @State private var showPlatformSheet = false

    var body: some View {
        List {
            // Connected platforms
            Section {
                if !storage.letterboxdUsername.isEmpty {
                    HStack(spacing: 12) {
                        Text("🎬").font(.title3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Letterboxd").font(.body)
                            Text("@\(storage.letterboxdUsername)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                if storage.kinopoiskConnected {
                    HStack(spacing: 12) {
                        Text("🎥").font(.title3)
                        Text("Кинопоиск")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                if storage.imdbConnected {
                    HStack(spacing: 12) {
                        Text("⭐").font(.title3)
                        Text("IMDB")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                Button { showPlatformSheet = true } label: {
                    Label(storage.hasAnyPlatform ? "Управление платформами" : "Подключить платформу",
                          systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Платформы")
            }

            // Letterboxd notification toggles
            Section {
                Toggle(isOn: $settings.notifWatchedEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Просмотренные")
                            Text("Фильм засинчен как просмотренный")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "eye.fill").foregroundStyle(.green)
                    }
                }

                Toggle(isOn: $settings.notifWatchlistEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Watchlist")
                            Text("Фильм добавлен в «хочу посмотреть»")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "bookmark.fill").foregroundStyle(.blue)
                    }
                }

                Toggle(isOn: $settings.notifLessonEnabled) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Уроки по фильмам")
                            Text("Слова и квиз по новому фильму готовы")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "book.fill").foregroundStyle(.purple)
                    }
                }
            } header: {
                Text("Уведомления кино")
            } footer: {
                Text("Настройте, какие уведомления приходят при синхронизации Letterboxd")
            }
        }
        .navigationTitle("Кино")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPlatformSheet) {
            PlatformConnectSheet()
        }
    }
}

// MARK: - Language Settings Page
struct LanguageSettingsPage: View {
    @ObservedObject var settings = ProfileSettings.shared

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LanguagePickerSheet(value: settings.learningLanguage) {
                        settings.learningLanguage = $0
                    }
                } label: {
                    let lang = LanguageConfig.find(settings.learningLanguage)
                    HStack {
                        Text("\(lang.flag) \(lang.name)")
                        Spacer()
                        Text(lang.code).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Изучаемый язык")
            }

            Section {
                Picker("Слов в день", selection: $settings.wordsDailyGoal) {
                    ForEach([5, 10, 15, 20, 30], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }

                NavigationLink {
                    PickerPage(title: "Личность AI",
                               options: ["Мотивирующий","Аналитичный","Balanced","Строгий","Дружелюбный"],
                               selected: $settings.aiPersonality)
                } label: {
                    HStack {
                        Text("Личность AI-учителя")
                        Spacer()
                        Text(settings.aiPersonality).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Обучение")
            }

            Section {
                NavigationLink {
                    EditTextSheet(title: "Letterboxd username",
                                  value: settings.letterboxdUsername) {
                        settings.letterboxdUsername = $0
                    }
                } label: {
                    HStack {
                        Text("Letterboxd")
                        Spacer()
                        Text(settings.letterboxdUsername.isEmpty ? "Не подключён" : "@\(settings.letterboxdUsername)")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Интеграции")
            }
        }
        .navigationTitle("Языки")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Food Settings Page
struct FoodSettingsPage: View {
    @ObservedObject var settings = ProfileSettings.shared

    var body: some View {
        List {
            Section {
                Picker("Цель калорий", selection: $settings.calorieGoal) {
                    ForEach([1400,1600,1800,2000,2200,2500,2800,3000,3500], id: \.self) { n in
                        Text("\(n) ккал").tag(n)
                    }
                }

                Picker("Единицы", selection: $settings.units) {
                    Text("Метрика").tag("Metric")
                    Text("Имперская").tag("Imperial")
                }
            } header: {
                Text("Цели")
            }

            Section {
                Toggle(isOn: $settings.notifFoodEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Напоминания о еде")
                        Text("Завтрак, обед, ужин").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Уведомления")
            }
        }
        .navigationTitle("Питание")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Route Settings Page
struct RouteSettingsPage: View {
    @ObservedObject var settings = ProfileSettings.shared

    var body: some View {
        List {
            Section {
                NavigationLink {
                    EditTextSheet(title: "Мой город", value: settings.city) {
                        settings.city = $0
                    }
                } label: {
                    HStack {
                        Text("Город")
                        Spacer()
                        Text(settings.city.isEmpty ? "Не указан" : settings.city)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Время на сборы", selection: $settings.gatheringTime) {
                    ForEach([5,10,15,20,30,45,60], id: \.self) { n in
                        Text("\(n) мин").tag(n)
                    }
                }

                Picker("Начало недели", selection: $settings.weekStart) {
                    Text("Понедельник").tag("Monday")
                    Text("Воскресенье").tag("Sunday")
                }
            } header: {
                Text("Общее")
            }

            Section {
                Toggle(isOn: $settings.notifRouteEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Время выезда")
                        Text("Напоминание за 15 мин до отправления")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Уведомления")
            }
        }
        .navigationTitle("Маршруты")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Notification Settings Page
struct NotificationSettingsPage: View {
    @ObservedObject var settings = ProfileSettings.shared

    var body: some View {
        List {
            Section {
                Toggle(isOn: $settings.notifWatchedEnabled) {
                    NotifToggleLabel(icon: "eye.fill", color: .green,
                                     title: "Фильм просмотрен",
                                     desc: "Letterboxd → просмотренные")
                }
                Toggle(isOn: $settings.notifWatchlistEnabled) {
                    NotifToggleLabel(icon: "bookmark.fill", color: .blue,
                                     title: "Watchlist",
                                     desc: "Letterboxd → хочу посмотреть")
                }
                Toggle(isOn: $settings.notifLessonEnabled) {
                    NotifToggleLabel(icon: "book.fill", color: .purple,
                                     title: "Урок готов",
                                     desc: "Слова и квиз по новому фильму")
                }
            } header: {
                Text("Кино")
            }

            Section {
                Toggle(isOn: $settings.notifQuizEnabled) {
                    NotifToggleLabel(icon: "brain", color: .pink,
                                     title: "Квиз-напоминание",
                                     desc: "Ежедневные повторения")
                }
                Toggle(isOn: $settings.notifStreakEnabled) {
                    NotifToggleLabel(icon: "flame.fill", color: .orange,
                                     title: "Streak",
                                     desc: "Не потеряй свою серию")
                }
            } header: {
                Text("Обучение")
            }

            Section {
                Toggle(isOn: $settings.notifFoodEnabled) {
                    NotifToggleLabel(icon: "fork.knife", color: .green,
                                     title: "Приёмы пищи",
                                     desc: "Завтрак, обед, ужин")
                }
            } header: {
                Text("Питание")
            }

            Section {
                Toggle(isOn: $settings.notifRouteEnabled) {
                    NotifToggleLabel(icon: "car.fill", color: .orange,
                                     title: "Время выезда",
                                     desc: "За 15 мин до отправления")
                }
            } header: {
                Text("Маршруты")
            }
        }
        .navigationTitle("Уведомления")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotifToggleLabel: View {
    let icon: String; let color: Color; let title: String; let desc: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Appearance Settings Page
struct AppearanceSettingsPage: View {
    @ObservedObject var settings = ProfileSettings.shared

    var body: some View {
        List {
            Section {
                Picker("Тема", selection: $settings.darkMode) {
                    Text("Светлая").tag("Светлая")
                    Text("Тёмная").tag("Тёмная")
                    Text("Системная").tag("Системная")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Тема приложения")
            }

            Section {
                Toggle(isOn: $settings.hapticEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Тактильный отклик")
                        Text("Вибрация при нажатиях")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Обратная связь")
            }
        }
        .navigationTitle("Оформление")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About App Page
struct AboutAppPage: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(colors: [.blue, .purple],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: .blue.opacity(0.3), radius: 12, y: 4)
                            Text("A")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text("AURA")
                            .font(.title2.bold())
                        Text("Версия 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            }

            Section {
                AboutFeatureRow(icon: "film.fill", color: .purple,
                                title: "Кино-дневник",
                                desc: "Синхронизация с Letterboxd, слова из фильмов, квизы")
                AboutFeatureRow(icon: "character.book.closed.fill", color: .blue,
                                title: "Изучение языков",
                                desc: "Слова, контекст, повторения через кино")
                AboutFeatureRow(icon: "fork.knife", color: .green,
                                title: "Трекер питания",
                                desc: "AI-анализ фото еды, подсчёт калорий")
                AboutFeatureRow(icon: "location.fill", color: .orange,
                                title: "Маршруты",
                                desc: "Умные маршруты, пробки, время выезда")
            } header: {
                Text("Возможности")
            }

            Section {
                LabeledContent("Разработчик", value: "AURA Team")
                LabeledContent("Платформа", value: "iOS 17+")
                LabeledContent("AI", value: "Gemini, TMDB")
            } header: {
                Text("Информация")
            }
        }
        .navigationTitle("О приложении")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutFeatureRow: View {
    let icon: String; let color: Color; let title: String; let desc: String
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Change Password Sheet
struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isDone = false

    var body: some View {
        NavigationStack {
            Form {
                if !isDone {
                    Section {
                        SecureField("Текущий пароль", text: $currentPassword)
                        SecureField("Новый пароль", text: $newPassword)
                        SecureField("Подтвердите новый пароль", text: $confirmPassword)
                    } header: {
                        Text("Смена пароля")
                    } footer: {
                        Text("Минимум 6 символов")
                    }

                    if !errorMessage.isEmpty {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Section {
                        Button(action: { Task { await changePassword() } }) {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text("Сменить пароль")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(isLoading)
                    }
                } else {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.green)
                                Text("Пароль изменён")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Пароль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isDone ? "Готово" : "Отмена") { dismiss() }
                }
            }
        }
    }

    func changePassword() async {
        guard !currentPassword.isEmpty else { errorMessage = "Введите текущий пароль"; return }
        guard newPassword.count >= 6 else { errorMessage = "Минимум 6 символов"; return }
        guard newPassword == confirmPassword else { errorMessage = "Пароли не совпадают"; return }

        isLoading = true; errorMessage = ""
        do {
            let _ = try await NetworkManager.shared.changePassword(
                currentPassword: currentPassword, newPassword: newPassword
            )
            withAnimation { isDone = true }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Privacy Page
struct PrivacyPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Политика конфиденциальности")
                    .font(.title2.bold())

                Group {
                    Text("Ваши данные").font(.headline)
                    Text("AURA хранит данные аккаунта (email, имя) и пользовательские настройки на защищённых серверах. Фото еды обрабатываются AI и не сохраняются после анализа.")

                    Text("Letterboxd").font(.headline)
                    Text("Приложение использует публичный RSS-фид Letterboxd для синхронизации фильмов. Мы не имеем доступа к вашему паролю Letterboxd.")

                    Text("Третьи стороны").font(.headline)
                    Text("Для работы используются API: TMDB (фильмы), Google Gemini (AI), 2GIS (маршруты). Данные передаются в зашифрованном виде.")

                    Text("Удаление данных").font(.headline)
                    Text("Вы можете удалить свой аккаунт и все данные в разделе Профиль → Удалить аккаунт. Удаление необратимо.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Конфиденциальность")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Compatibility Components (used by other views)

struct SettingsCard<Content: View>: View {
    let title: String; let icon: String; let iconColor: Color
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(iconColor)
                Text(title.uppercased()).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct SettingsIcon: View {
    let systemName: String; let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient).frame(width: 30, height: 30)
            Image(systemName: systemName).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
        }
    }
}

struct SettingsDivider: View {
    var body: some View { Divider().padding(.leading, 58) }
}

struct ToggleRow: View {
    let icon: String; let iconColor: Color; let title: String; let subtitle: String?
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.body)
                if let sub = subtitle { Text(sub).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct InfoRow: View {
    let icon: String; let iconColor: Color; let title: String; let value: String
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: iconColor)
            Text(title).font(.body)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

struct TextInputRow<Destination: View>: View {
    let icon: String; let iconColor: Color; let title: String; let value: String
    @ViewBuilder let destination: () -> Destination
    var body: some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 12) {
                SettingsIcon(systemName: icon, color: iconColor)
                Text(title).font(.body).foregroundStyle(.primary)
                Spacer()
                Text(value).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}

struct NavigationPickerRow<Destination: View>: View {
    let icon: String; let iconColor: Color; let title: String; let value: String
    @ViewBuilder let destination: () -> Destination
    var body: some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 12) {
                SettingsIcon(systemName: icon, color: iconColor)
                Text(title).font(.body).foregroundStyle(.primary)
                Spacer()
                Text(value).font(.subheadline).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}

struct SegmentedRow: View {
    let title: String; let icon: String; let iconColor: Color
    let options: [String]; @Binding var selected: String
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: iconColor)
            Text(title).font(.body)
            Spacer()
            Picker("", selection: $selected) {
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).frame(maxWidth: 180)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct ContextMenuRow: View {
    let icon: String; let label: String; let color: Color; let delay: Double; let action: () -> Void
    @State private var appeared = false; @State private var pressed = false
    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(color).frame(width: 22)
                Text(label).font(.system(size: 15)).foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background(pressed ? Color(.systemGray5) : Color.clear).contentShape(Rectangle())
        }
        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : -4)
        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay), value: appeared)
        ._onButtonGesture { p in withAnimation(.easeInOut(duration: 0.1)) { pressed = p } } perform: {}
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { appeared = true } }
    }
}

// MARK: - Picker Pages
struct PickerPage: View {
    let title: String; let options: [String]; @Binding var selected: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        List {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation { selected = option }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    HStack {
                        Text(option).foregroundStyle(.primary)
                        Spacer()
                        if selected == option {
                            Image(systemName: "checkmark").foregroundStyle(.blue).fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct PickerIntPage: View {
    let title: String; let options: [Int]; @Binding var selected: Int
    @Environment(\.dismiss) var dismiss
    var body: some View {
        List {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation { selected = option }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    HStack {
                        Text("\(option)").foregroundStyle(.primary)
                        Spacer()
                        if selected == option {
                            Image(systemName: "checkmark").foregroundStyle(.blue).fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct EditTextSheet: View {
    let title: String; @State private var text: String; let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    init(title: String, value: String, onSave: @escaping (String) -> Void) {
        self.title = title; self._text = State(initialValue: value); self.onSave = onSave
    }
    var body: some View {
        Form { TextField(title, text: $text) }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(text); dismiss() } } }
    }
}

struct EditPickerSheet: View {
    let title: String; @State private var selected: Int; let options: [Int]; let onSave: (Int) -> Void
    @Environment(\.dismiss) var dismiss
    init(title: String, value: Int, options: [Int], onSave: @escaping (Int) -> Void) {
        self.title = title; self._selected = State(initialValue: value); self.options = options; self.onSave = onSave
    }
    var body: some View {
        Form { Picker(title, selection: $selected) { ForEach(options, id: \.self) { Text("\($0)").tag($0) } }.pickerStyle(.wheel) }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(selected); dismiss() } } }
    }
}

struct EditSegmentSheet: View {
    let title: String; @State private var selected: String; let options: [String]; let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    init(title: String, value: String, options: [String], onSave: @escaping (String) -> Void) {
        self.title = title; self._selected = State(initialValue: value); self.options = options; self.onSave = onSave
    }
    var body: some View {
        Form { Picker(title, selection: $selected) { ForEach(options, id: \.self) { Text($0).tag($0) } }.pickerStyle(.inline) }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { onSave(selected); dismiss() } } }
    }
}

struct StatCell: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }
}

struct CinemaPlatformSettingsCard: View {
    @StateObject private var storage = CinemaStorage.shared
    @State private var showPlatformSheet = false
    var body: some View {
        SettingsCard(title: "Кино-платформы", icon: "film.fill", iconColor: .purple) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    SettingsIcon(systemName: "link.circle.fill", color: storage.hasAnyPlatform ? .green : .gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Подключено платформ").font(.caption).foregroundStyle(.secondary)
                        if storage.hasAnyPlatform {
                            Text(storage.connectedPlatformNames.joined(separator: ", ")).font(.body)
                        } else {
                            Text("Нет подключённых платформ").font(.body).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }.padding(.horizontal, 16).padding(.vertical, 12)
                SettingsDivider()
                Button { showPlatformSheet = true } label: {
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: storage.hasAnyPlatform ? "gearshape" : "plus.circle.fill", color: .blue)
                        Text(storage.hasAnyPlatform ? "Управление платформами" : "Подключить платформу").font(.body).foregroundStyle(.blue)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }.padding(.horizontal, 16).padding(.vertical, 12)
                }
            }
        }.sheet(isPresented: $showPlatformSheet) { PlatformConnectSheet() }
    }
}

struct CinemaPlatformRow: View {
    let emoji: String; let name: String; let detail: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Text(emoji).font(.title3).frame(width: 30, height: 30)
                .background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.subheadline).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(color)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(color).font(.subheadline)
        }.padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// Keep AccentTheme for any external references
enum AccentTheme: String, CaseIterable {
    case blue = "Blue", purple = "Purple", orange = "Orange", green = "Green", pink = "Pink", indigo = "Indigo"
    var color: Color {
        switch self {
        case .blue: return .blue; case .purple: return .purple; case .orange: return .orange
        case .green: return .green; case .pink: return .pink; case .indigo: return .indigo
        }
    }
}

// Keep StatPill for any external references
struct StatPill: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(color)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 14)
    }
}
