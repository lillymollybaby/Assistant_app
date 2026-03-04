import Foundation
import Combine
import SwiftUI
import BackgroundTasks

// MARK: - Letterboxd RSS Entry
struct LetterboxdEntry: Identifiable {
    let id: String           // guid из RSS
    let title: String        // "The Shining, 1980"
    let movieTitle: String   // "The Shining"
    let year: String?        // "1980"
    let rating: Double?      // звёзды 0.5-5.0
    let watchedDate: Date?   // дата просмотра
    let link: String?        // ссылка на Letterboxd
}

// MARK: - Sync Service
@MainActor
class LetterboxdSyncService: ObservableObject {
    static let shared = LetterboxdSyncService()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncedCount = 0
    @Published var watchlistSyncedCount = 0
    @Published var lastError: String?
    @Published var syncLog: [String] = []        // подробный лог для отладки
    @Published var totalRSSEntries = 0           // сколько всего записей в RSS
    @Published var newEntriesFound = 0            // сколько новых (не засинченных)

    private let syncedIDsKey = "letterboxd_synced_ids"
    private let watchlistSyncedIDsKey = "letterboxd_watchlist_synced_ids"
    private let lastSyncKey = "letterboxd_last_sync"

    // Background task identifier
    static let bgTaskIdentifier = "com.aura.letterboxd.sync"

    // Уже засинченные ID фильмов (чтобы не дублировать)
    private var syncedIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: syncedIDsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: syncedIDsKey)
        }
    }

    // Уже засинченные ID из watchlist
    private var watchlistSyncedIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: watchlistSyncedIDsKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: watchlistSyncedIDsKey)
        }
    }

    init() {
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date

        // Одноразовый ресет — очищаем неверно сохранённые syncedIDs (v2 fix)
        let resetKey = "letterboxd_syncfix_v2"
        if !UserDefaults.standard.bool(forKey: resetKey) {
            syncedIDs = []
            watchlistSyncedIDs = []
            lastSyncDate = nil
            UserDefaults.standard.removeObject(forKey: lastSyncKey)
            UserDefaults.standard.set(true, forKey: resetKey)
            print("[Letterboxd] 🔄 Одноразовый ресет syncedIDs (v2 fix)")
        }
    }

    // MARK: - Main Sync Flow

    /// Полный цикл: RSS → парсинг → поиск TMDB → markWatched → push
    func syncLetterboxd() async {
        let username = CinemaStorage.shared.letterboxdUsername
        guard !username.isEmpty else {
            lastError = "Letterboxd username не указан"
            return
        }
        guard !isSyncing else { return }

        isSyncing = true
        lastError = nil
        syncedCount = 0
        watchlistSyncedCount = 0
        syncLog = []
        totalRSSEntries = 0
        newEntriesFound = 0

        log("⏳ Синк для @\(username)...")

        do {
            // 1. Загрузить RSS
            let entries = try await fetchRSS(username: username)
            totalRSSEntries = entries.count
            log("📡 RSS загружен: \(entries.count) записей")

            if entries.isEmpty {
                log("⚠️ RSS пустой — проверь, что профиль публичный")
                isSyncing = false
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
                return
            }

            // Показать последние 3 записи из RSS для отладки
            for (i, e) in entries.prefix(3).enumerated() {
                log("  #\(i+1): \"\(e.movieTitle)\" (\(e.year ?? "?")) id=\(e.id.prefix(30))")
            }

            // 2. Отфильтровать только новые (ещё не засинченные)
            let newEntries = entries.filter { !syncedIDs.contains($0.id) }
            newEntriesFound = newEntries.count

            guard !newEntries.isEmpty else {
                log("✅ Все \(entries.count) фильмов уже засинчены")
                isSyncing = false
                lastSyncDate = Date()
                UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
                return
            }

            log("🆕 Новых для синка: \(newEntries.count)")

            // 3. Для каждого нового — найти на TMDB и добавить
            for entry in newEntries {
                do {
                    // Поиск по названию и году
                    let searchQuery = entry.year != nil ? "\(entry.movieTitle) \(entry.year!)" : entry.movieTitle
                    log("🔍 Ищу: \"\(searchQuery)\"")
                    let results = try await NetworkManager.shared.searchMovies(query: searchQuery)
                    log("   Найдено результатов TMDB: \(results.count)")

                    // Найти лучшее совпадение
                    if let match = findBestMatch(entry: entry, in: results) {
                        let tmdbId = match.stableId
                        log("   ✔ Совпадение: \"\(match.title)\" (tmdb: \(tmdbId))")

                        // Отметить как просмотренное
                        let _ = try await NetworkManager.shared.markWatched(tmdbId: tmdbId)
                        log("   ✅ Отмечено как просмотренное")

                        // Push-уведомление
                        NotificationManager.shared.sendMovieLoggedNotification(
                            movieTitle: match.title, tmdbId: tmdbId
                        )

                        // Через 5 сек — уведомление о готовом уроке
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            NotificationManager.shared.sendLessonReadyNotification(
                                movieTitle: match.title,
                                wordCount: Int.random(in: 8...25),
                                tmdbId: tmdbId
                            )
                        }

                        syncedCount += 1

                        // Запомнить как обработанный ТОЛЬКО после успешного сохранения
                        syncedIDs.insert(entry.id)
                    } else {
                        log("   ⚠️ Не найдено совпадений для \"\(entry.movieTitle)\"")
                        // Не найден на TMDB — тоже запомнить чтобы не искать повторно
                        syncedIDs.insert(entry.id)
                    }

                } catch {
                    // НЕ добавляем в syncedIDs — будет повторная попытка при следующем синке
                    log("   ❌ Ошибка: \(error.localizedDescription)")
                    print("Letterboxd sync: ошибка для \(entry.movieTitle): \(error)")
                }

                // Небольшая задержка между запросами
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            log("🏁 Синк просмотренных завершён: \(syncedCount) добавлено")

        } catch {
            lastError = error.localizedDescription
            log("❌ Глобальная ошибка (watched): \(error.localizedDescription)")
        }

        // 2. Синк watchlist
        await syncWatchlist(username: username)

        log("🏁 Полный синк завершён: \(syncedCount) watched, \(watchlistSyncedCount) watchlist")
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
        isSyncing = false
    }

    // MARK: - Watchlist Sync

    /// Синк watchlist из Letterboxd → добавить в "Хочу посмотреть"
    private func syncWatchlist(username: String) async {
        log("📋 Синк watchlist для @\(username)...")

        do {
            let entries = try await fetchWatchlistRSS(username: username)
            log("📋 Watchlist RSS: \(entries.count) записей")

            guard !entries.isEmpty else {
                log("📋 Watchlist пуст")
                return
            }

            let newEntries = entries.filter { !watchlistSyncedIDs.contains($0.id) }
            guard !newEntries.isEmpty else {
                log("✅ Все \(entries.count) из watchlist уже засинчены")
                return
            }

            log("🆕 Новых для watchlist: \(newEntries.count)")

            for entry in newEntries {
                do {
                    let searchQuery = entry.year != nil ? "\(entry.movieTitle) \(entry.year!)" : entry.movieTitle
                    log("🔍 Watchlist ищу: \"\(searchQuery)\"")
                    let results = try await NetworkManager.shared.searchMovies(query: searchQuery)

                    if let match = findBestMatch(entry: entry, in: results) {
                        let tmdbId = match.stableId
                        log("   ✔ Совпадение: \"\(match.title)\" (tmdb: \(tmdbId))")

                        let _ = try await NetworkManager.shared.addToWatchlist(tmdbId: tmdbId)
                        log("   🔖 Добавлено в watchlist")

                        NotificationManager.shared.sendWatchlistNotification(
                            movieTitle: match.title, tmdbId: tmdbId
                        )

                        watchlistSyncedCount += 1
                        watchlistSyncedIDs.insert(entry.id)
                    } else {
                        log("   ⚠️ Не найдено: \"\(entry.movieTitle)\"")
                        watchlistSyncedIDs.insert(entry.id)
                    }
                } catch {
                    log("   ❌ Ошибка watchlist: \(error.localizedDescription)")
                }

                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        } catch {
            log("❌ Ошибка watchlist RSS: \(error.localizedDescription)")
        }
    }

    /// Загрузить RSS watchlist Letterboxd
    func fetchWatchlistRSS(username: String) async throws -> [LetterboxdEntry] {
        let urlString = "https://letterboxd.com/\(username)/watchlist/rss/"
        guard let url = URL(string: urlString) else {
            throw LetterboxdError.invalidUsername
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("AURA-App/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LetterboxdError.networkError
        }

        switch httpResponse.statusCode {
        case 200: break
        case 404: throw LetterboxdError.userNotFound(username)
        default: throw LetterboxdError.serverError(httpResponse.statusCode)
        }

        let parser = LetterboxdRSSParser(data: data)
        return parser.parse()
    }

    private func log(_ message: String) {
        syncLog.append(message)
        print("[Letterboxd] \(message)")
    }

    // MARK: - RSS Fetching & Parsing

    /// Загрузить и распарсить RSS-ленту Letterboxd
    func fetchRSS(username: String) async throws -> [LetterboxdEntry] {
        let urlString = "https://letterboxd.com/\(username)/rss/"
        guard let url = URL(string: urlString) else {
            throw LetterboxdError.invalidUsername
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        // Letterboxd может блокировать без User-Agent
        request.setValue("AURA-App/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LetterboxdError.networkError
        }

        switch httpResponse.statusCode {
        case 200: break
        case 404: throw LetterboxdError.userNotFound(username)
        default: throw LetterboxdError.serverError(httpResponse.statusCode)
        }

        // Парсим XML
        let parser = LetterboxdRSSParser(data: data)
        return parser.parse()
    }

    // MARK: - TMDB Matching

    /// Находит лучшее совпадение из результатов поиска
    private func findBestMatch(entry: LetterboxdEntry, in results: [MovieResponse]) -> MovieResponse? {
        guard !results.isEmpty else { return nil }

        // Точное совпадение по названию + году
        if let year = entry.year {
            if let exact = results.first(where: {
                $0.title.lowercased() == entry.movieTitle.lowercased() && $0.year == year
            }) {
                return exact
            }
        }

        // Близкое совпадение по названию
        if let close = results.first(where: {
            $0.title.lowercased().contains(entry.movieTitle.lowercased()) ||
            entry.movieTitle.lowercased().contains($0.title.lowercased())
        }) {
            return close
        }

        // Если ничего не нашли — берём первый результат
        return results.first
    }

    // MARK: - Background Task Registration

    /// Зарегистрировать BGAppRefreshTask (вызывать из AppDelegate/App init)
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: bgTaskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                await LetterboxdSyncService.shared.syncLetterboxd()
                refreshTask.setTaskCompleted(success: true)
            }
            // Запланировать следующий
            scheduleBackgroundSync()
        }
    }

    /// Запланировать следующий background sync (каждые 30 мин)
    static func scheduleBackgroundSync() {
        let username = CinemaStorage.shared.letterboxdUsername
        guard !username.isEmpty else { return }

        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 минут

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Letterboxd BG sync schedule failed: \(error)")
        }
    }

    /// Сбросить историю синка (при смене пользователя)
    func resetSync() {
        syncedIDs = []
        watchlistSyncedIDs = []
        lastSyncDate = nil
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        syncedCount = 0
        watchlistSyncedCount = 0
    }
}

// MARK: - RSS XML Parser
class LetterboxdRSSParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var entries: [LetterboxdEntry] = []

    // Текущие значения при парсинге
    private var currentElement = ""
    private var currentTitle = ""
    private var currentGuid = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentRating = ""
    private var currentFilmTitle = ""   // <letterboxd:filmTitle>
    private var currentFilmYear = ""    // <letterboxd:filmYear>
    private var currentWatchedDate = "" // <letterboxd:watchedDate>
    private var isInItem = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [LetterboxdEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        // НЕ включаем namespace processing — чтобы получать "letterboxd:filmTitle" как есть
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.parse()
        return entries
    }

    // XMLParserDelegate
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentGuid = ""
            currentLink = ""
            currentPubDate = ""
            currentRating = ""
            currentFilmTitle = ""
            currentFilmYear = ""
            currentWatchedDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "guid": currentGuid += string
        case "link": currentLink += string
        case "pubDate": currentPubDate += string
        case "letterboxd:memberRating": currentRating += string
        case "letterboxd:filmTitle": currentFilmTitle += string
        case "letterboxd:filmYear": currentFilmYear += string
        case "letterboxd:watchedDate": currentWatchedDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" && isInItem {
            let filmTitle = currentFilmTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let filmYear = currentFilmYear.trimmingCharacters(in: .whitespacesAndNewlines)
            let rating = Double(currentRating.trimmingCharacters(in: .whitespacesAndNewlines))

            // Предпочитаем letterboxd:filmTitle, фоллбэк на парсинг <title>
            let movieTitle: String
            let year: String?
            if !filmTitle.isEmpty {
                movieTitle = filmTitle
                year = filmYear.isEmpty ? nil : filmYear
            } else {
                let parsed = parseTitle(currentTitle.trimmingCharacters(in: .whitespacesAndNewlines))
                movieTitle = parsed.title
                year = parsed.year
            }

            // watchedDate (letterboxd:watchedDate = "2024-01-15") или pubDate
            let date: Date?
            let trimmedWatched = currentWatchedDate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedWatched.isEmpty {
                date = parseISO8601Date(trimmedWatched)
            } else {
                date = parseRSSDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines))
            }

            let guid = currentGuid.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !guid.isEmpty && !movieTitle.isEmpty else {
                isInItem = false
                currentElement = ""
                return
            }

            let entry = LetterboxdEntry(
                id: guid,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                movieTitle: movieTitle,
                year: year,
                rating: rating,
                watchedDate: date,
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            entries.append(entry)
            isInItem = false
        }
        currentElement = ""
    }

    /// Фоллбэк: "The Shining, 1980" → (title: "The Shining", year: "1980")
    private func parseTitle(_ raw: String) -> (title: String, year: String?) {
        // Letterboxd title format: "MovieTitle, YEAR" или "MovieTitle, YEAR - ★★★½"
        let cleaned = raw.components(separatedBy: " - ").first ?? raw
        let parts = cleaned.components(separatedBy: ", ")
        if parts.count >= 2 {
            let yearCandidate = parts.last!.trimmingCharacters(in: .whitespaces)
            if yearCandidate.count == 4, Int(yearCandidate) != nil {
                let title = parts.dropLast().joined(separator: ", ")
                return (title: title, year: yearCandidate)
            }
        }
        return (title: cleaned, year: nil)
    }

    /// Parse RFC 822 date from RSS pubDate
    private func parseRSSDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: string)
    }

    /// Parse ISO 8601 date ("2024-01-15") from letterboxd:watchedDate
    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}

// MARK: - Errors
enum LetterboxdError: Error, LocalizedError {
    case invalidUsername
    case userNotFound(String)
    case networkError
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidUsername: return "Некорректный username Letterboxd"
        case .userNotFound(let u): return "Пользователь @\(u) не найден на Letterboxd"
        case .networkError: return "Ошибка соединения с Letterboxd"
        case .serverError(let code): return "Letterboxd ответил ошибкой (\(code))"
        }
    }
}
