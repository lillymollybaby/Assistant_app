import Foundation

// MARK: - Models
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let user: UserResponse
}

struct UserResponse: Codable {
    let id: Int
    let email: String
    let username: String?
    let full_name: String?
    let avatar_url: String?
    let is_verified: Bool?
    let calorie_goal: Int?
    let protein_goal: Int?
    let carbs_goal: Int?
    let fat_goal: Int?
    let step_goal: Int?
    let created_at: String?
}

struct MessageResponse: Codable {
    let message: String
}

struct PreferencesResponse: Codable {
    let preferences: [String: AnyCodableValue]
}

/// A type-erased Codable value for preferences JSON
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else { self = .null }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
    
    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var intValue: Int? { if case .int(let v) = self { return v }; return nil }
    var doubleValue: Double? { if case .double(let v) = self { return v }; return nil }
    var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
}

struct DailySummaryResponse: Codable {
    let date: String?
    let total_calories: Double
    let total_proteins: Double
    let total_fats: Double
    let total_carbs: Double
    let meals: [MealResponse]?
    let ai_advice: String?
    let calorie_goal: Int?      // реальная цель с сервера (может отсутствовать)
    let protein_goal: Int?
    let fat_goal: Int?
    let carbs_goal: Int?

    // Обратная совместимость
    var total_protein: Double { total_proteins }
    var total_fat: Double { total_fats }
    var total_carbs_compat: Double { total_carbs }
    var meals_count: Int { meals?.count ?? 0 }
}

struct MealResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let calories: Double
    let proteins: Double
    let fats: Double
    let carbs: Double
    let meal_type: String?
    let eaten_at: String?
    let ai_analysis: String?
    
    var protein: Double { proteins }
    var fat: Double { fats }
    var created_at: String? { eaten_at }
}

struct MovieResponse: Codable, Identifiable {
    let id: Int?
    let tmdb_id: Int?
    let title: String
    let year: String?
    let rating: Double?
    let poster_url: String?
    let watched: Bool?
    let review: String?
    
    var stableId: Int { tmdb_id ?? id ?? title.hashValue }
    
    enum CodingKeys: String, CodingKey {
        case id, tmdb_id, title, year, rating, poster_url, watched, review
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        tmdb_id = try c.decodeIfPresent(Int.self, forKey: .tmdb_id)
        title = try c.decode(String.self, forKey: .title)
        rating = try c.decodeIfPresent(Double.self, forKey: .rating)
        poster_url = try c.decodeIfPresent(String.self, forKey: .poster_url)
        watched = try c.decodeIfPresent(Bool.self, forKey: .watched)
        review = try c.decodeIfPresent(String.self, forKey: .review)
        // year may come as Int or String from backend
        if let intYear = try? c.decodeIfPresent(Int.self, forKey: .year) {
            year = String(intYear)
        } else {
            year = try? c.decodeIfPresent(String.self, forKey: .year)
        }
    }
    
    init(id: Int?, tmdb_id: Int?, title: String, year: String?, rating: Double?, poster_url: String?, watched: Bool?, review: String?) {
        self.id = id
        self.tmdb_id = tmdb_id
        self.title = title
        self.year = year
        self.rating = rating
        self.poster_url = poster_url
        self.watched = watched
        self.review = review
    }
}

struct CastMember: Codable {
    let name: String
    let character: String
    let profile_url: String?
}

struct MovieDetails: Codable {
    let tmdb_id: Int
    let title: String
    let original_title: String?
    let year: String?
    let rating: Double?
    let vote_count: Int?
    let runtime: Int?
    let overview: String?
    let poster_url: String?
    let backdrop_url: String?
    let genres: [String]?
    let cast: [CastMember]?
    let directors: [String]?
    let writers: [String]?
    let tagline: String?
    let original_language: String?
}

struct MovieWord: Codable, Identifiable {
    var id: String { word }
    let word: String
    let translation: String
    let context: String?
    let example: String?
}

struct MovieWordsResponse: Codable {
    let title: String
    let level: String
    let words: [MovieWord]
}

struct MovieSearchResult: Codable {
    let results: [MovieResponse]
}

struct VocabResponse: Codable {
    let id: Int
    let word: String
    let translation: String
    let example: String?
    let language: String?
    let learned: Bool
}

struct StreakResponse: Codable {
    let total_words: Int?
    let learned_words: Int?
    let streak_days: Int
    let progress_percent: Int?
}

struct PlaceResult: Codable {
    let name: String
    let address: String?
    let lat: Double?
    let lon: Double?
    let type: String?
}

struct PlaceSearchResponse: Codable {
    let results: [PlaceResult]
}

struct RouteResponse: Codable {
    let distance_km: Double
    let duration_min: Int
    let status: String
}

struct TrafficAdviceResponse: Codable {
    let destination: String
    let traffic_status: String
    let advice: String
    let hour: Int
}

struct DinnerIdeasResponse: Codable {
    let ideas: String
    let calories_remaining: Double
}


// MARK: - Auth Storage (Keychain)
class AuthStorage {
    static let shared = AuthStorage()
    private let tokenKey = "auth_token"
    private let service  = "com.aura.app"

    var token: String? {
        get { keychainGet() }
        set {
            if let value = newValue { keychainSet(value) }
            else { keychainDelete() }
        }
    }

    var isLoggedIn: Bool {
        guard let t = token else { return false }
        return !t.isEmpty
    }

    func logout() { keychainDelete() }

    // MARK: Keychain helpers
    private func keychainGet() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      tokenKey,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var ref: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &ref)
        guard status == errSecSuccess,
              let data = ref as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    private func keychainSet(_ value: String) {
        keychainDelete() // удаляем старое перед записью
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     tokenKey,
            kSecValueData:       data,
            // доступен только когда устройство разблокировано, не синхронизируется в iCloud
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainDelete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Error
enum APIError: Error, LocalizedError {
    case networkError       // неверный URL
    case noInternet         // нет соединения
    case serverError(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .networkError:        return "Ошибка соединения"
        case .noInternet:          return "Нет интернета. Проверьте подключение."
        case .serverError(let msg): return msg
        case .unauthorized:        return "Сессия истекла. Войдите снова."
        }
    }

    var isNoInternet: Bool {
        if case .noInternet = self { return true }
        return false
    }
}

// MARK: - Network Manager
class NetworkManager {
    static let shared = NetworkManager()
    let BASE_URL = "https://aura-api.ddns.net"
    let session = URLSession.shared
    
    private func authHeaders() -> [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let token = AuthStorage.shared.token {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers
    }
    
    func request<T: Codable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        guard let url = URL(string: BASE_URL + path) else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = method
        authHeaders().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
                 .timedOut, .dnsLookupFailed:
                throw APIError.noInternet
            default:
                throw APIError.networkError
            }
        }
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            AuthStorage.shared.logout()
            await MainActor.run {
                NotificationCenter.default.post(name: .didLogout, object: nil)
            }
            throw APIError.unauthorized
        }
        // Логировать все не-2xx ответы
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("[API] ❌ \(method) \(path) → \(httpResponse.statusCode): \(body)")
            throw APIError.serverError("HTTP \(httpResponse.statusCode): \(body)")
        }
        guard let result = try? JSONDecoder().decode(T.self, from: data) else {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
            print("[API] ⚠️ Decode failed for \(method) \(path): \(errStr.prefix(200))")
            throw APIError.serverError(errStr)
        }
        return result
    }
    
    // MARK: - Auth
    func login(email: String, password: String) async throws -> TokenResponse {
        guard let url = URL(string: BASE_URL + "/auth/login") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        // URL-encode чтобы спецсимволы (&, =, +, #) в пароле не ломали form-data
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: email),
            URLQueryItem(name: "password", value: password)
        ]
        req.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        let (data, _) = try await session.data(for: req)
        guard let result = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw APIError.serverError("Неверный email или пароль")
        }
        return result
    }
    
    func register(email: String, password: String, name: String) async throws -> TokenResponse {
        guard let url = URL(string: BASE_URL + "/auth/register") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["username": email, "email": email, "password": password, "full_name": name]
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(errStr)
        }
        guard let result = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw APIError.serverError("Ошибка регистрации")
        }
        return result
    }
    
    func getMe() async throws -> UserResponse {
        return try await request("/auth/me")
    }
    
    // MARK: - Food
    func getTodaySummary() async throws -> DailySummaryResponse {
        return try await request("/food/today")
    }
    
    func getMealHistory() async throws -> [MealResponse] {
        return try await request("/food/history")
    }
    
    func analyzeFoodPhoto(imageData: Data, mealType: String = "snack") async throws -> MealResponse {
        guard let url = URL(string: BASE_URL + "/food/analyze-photo?meal_type=\(mealType)") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = AuthStorage.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let boundary = UUID().uuidString
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            AuthStorage.shared.logout()
            await MainActor.run {
                NotificationCenter.default.post(name: .didLogout, object: nil)
            }
            throw APIError.unauthorized
        }
        guard let result = try? JSONDecoder().decode(MealResponse.self, from: data) else {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errStr)
        }
        return result
    }
    
    func getDinnerIdeas() async throws -> DinnerIdeasResponse {
        return try await request("/food/dinner-ideas", method: "POST")
    }
    
    func deleteMeal(id: Int) async throws {
        let _: [String: String] = try await request("/food/meal/\(id)", method: "DELETE")
    }
    
    // MARK: - Cinema
    func getTrending() async throws -> [MovieResponse] {
        let response: MovieSearchResult = try await request("/cinema/trending")
        return response.results
    }
    
    func getMyMovies() async throws -> [MovieResponse] {
        return try await request("/cinema/my-list")
    }
    
    func getMovieDetails(tmdbId: Int) async throws -> MovieDetails {
        return try await request("/cinema/movie/\(tmdbId)")
    }
    
    func addToWatchlist(tmdbId: Int) async throws -> [String: String] {
        return try await request("/cinema/watchlist/\(tmdbId)", method: "POST")
    }
    
    func getMovieWords(tmdbId: Int, level: String = "intermediate") async throws -> MovieWordsResponse {
        return try await request("/cinema/words/\(tmdbId)?level=\(level)", method: "POST")
    }
    
    func getFilmCritique(tmdbId: Int) async throws -> String {
        struct CritiqueResponse: Codable {
            let critique: String?
            let title: String?
        }
        let response: CritiqueResponse = try await request("/cinema/film-critic/\(tmdbId)", method: "POST")
        return response.critique ?? "Рецензия недоступна"
    }
    
    func searchMovies(query: String) async throws -> [MovieResponse] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: MovieSearchResult = try await request("/cinema/search?q=\(encoded)")
        return response.results
    }
    
    func markWatched(tmdbId: Int, review: String? = nil) async throws -> MovieResponse {
        var path = "/cinema/watched/\(tmdbId)"
        if let review = review {
            let encoded = review.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? review
            path += "?review=\(encoded)"
        }
        return try await request(path, method: "POST")
    }
    
    // MARK: - Languages
    func getVocabulary() async throws -> [VocabResponse] {
        return try await request("/languages/vocabulary")
    }
    
    func getLearningStreak() async throws -> Int {
        let response: StreakResponse = try await request("/languages/streak")
        return response.streak_days
    }
    
    func markWordLearned(wordId: Int) async throws {
        let _: [String: String] = try await request("/languages/vocabulary/\(wordId)/learned", method: "PATCH")
    }
    
    // MARK: - Logistics
    func searchPlace(query: String, lat: Double? = nil, lon: Double? = nil) async throws -> [PlaceResult] {
        var path = "/logistics/search-place?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        if let lat = lat, let lon = lon {
            path += "&lat=\(lat)&lon=\(lon)"
        }
        let response: PlaceSearchResponse = try await request(path)
        return response.results
    }
    
    func getRoute(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double) async throws -> RouteResponse {
        struct RouteRequest: Codable {
            let from_lat: Double
            let from_lon: Double
            let to_lat: Double
            let to_lon: Double
            let transport: String
        }
        let body = RouteRequest(from_lat: fromLat, from_lon: fromLon, to_lat: toLat, to_lon: toLon, transport: "car")
        return try await request("/logistics/route", method: "POST", body: body)
    }
    
    func getTrafficAdvice(destination: String) async throws -> TrafficAdviceResponse {
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destination
        return try await request("/logistics/traffic-advice?destination=\(encoded)")
    }
   
    func scanProduct(imageData: Data) async throws -> ScanResult {
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(BASE_URL)/food/scan-product")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = AuthStorage.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"label.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ScanResult.self, from: data)
    }
    
    // MARK: - Auth (new endpoints)
    
    func logout() async throws -> MessageResponse {
        return try await request("/auth/logout", method: "POST")
    }
    
    func verifyEmail(email: String, code: String) async throws -> MessageResponse {
        struct Body: Encodable { let email: String; let code: String }
        return try await request("/auth/verify-email", method: "POST", body: Body(email: email, code: code))
    }
    
    func resendVerification(email: String) async throws -> MessageResponse {
        struct Body: Encodable { let email: String }
        return try await request("/auth/resend-verification", method: "POST", body: Body(email: email))
    }
    
    func forgotPassword(email: String) async throws -> MessageResponse {
        struct Body: Encodable { let email: String }
        return try await request("/auth/forgot-password", method: "POST", body: Body(email: email))
    }
    
    func resetPassword(email: String, code: String, newPassword: String) async throws -> MessageResponse {
        struct Body: Encodable { let email: String; let code: String; let new_password: String }
        return try await request("/auth/reset-password", method: "POST", body: Body(email: email, code: code, new_password: newPassword))
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws -> MessageResponse {
        struct Body: Encodable { let current_password: String; let new_password: String }
        return try await request("/auth/change-password", method: "POST", body: Body(current_password: currentPassword, new_password: newPassword))
    }
    
    func deleteAccount() async throws -> MessageResponse {
        return try await request("/auth/me", method: "DELETE")
    }
    
    // MARK: - Preferences
    
    func getPreferences() async throws -> PreferencesResponse {
        return try await request("/preferences")
    }
    
    func savePreferences(_ prefs: [String: Any]) async throws -> PreferencesResponse {
        guard let url = URL(string: BASE_URL + "/preferences") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        authHeaders().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let wrapper: [String: Any] = ["preferences": prefs]
        req.httpBody = try JSONSerialization.data(withJSONObject: wrapper)
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            AuthStorage.shared.logout()
            await MainActor.run { NotificationCenter.default.post(name: .didLogout, object: nil) }
            throw APIError.unauthorized
        }
        guard let result = try? JSONDecoder().decode(PreferencesResponse.self, from: data) else {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errStr)
        }
        return result
    }
    
    func updatePreferences(_ prefs: [String: Any]) async throws -> PreferencesResponse {
        guard let url = URL(string: BASE_URL + "/preferences") else { throw APIError.networkError }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        authHeaders().forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let wrapper: [String: Any] = ["preferences": prefs]
        req.httpBody = try JSONSerialization.data(withJSONObject: wrapper)
        let (data, response) = try await session.data(for: req)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            AuthStorage.shared.logout()
            await MainActor.run { NotificationCenter.default.post(name: .didLogout, object: nil) }
            throw APIError.unauthorized
        }
        guard let result = try? JSONDecoder().decode(PreferencesResponse.self, from: data) else {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.serverError(errStr)
        }
        return result
    }
    
}
