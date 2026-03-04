import SwiftUI
import Combine

// MARK: - Cinema Storage
class CinemaStorage: ObservableObject {
    static let shared = CinemaStorage()

    @Published var letterboxdUsername: String {
        didSet { UserDefaults.standard.set(letterboxdUsername, forKey: "letterboxd_username") }
    }
    @Published var kinopoiskConnected: Bool {
        didSet { UserDefaults.standard.set(kinopoiskConnected, forKey: "kinopoisk_connected") }
    }
    @Published var imdbConnected: Bool {
        didSet { UserDefaults.standard.set(imdbConnected, forKey: "imdb_connected") }
    }
    @Published var kinopoiskUsername: String {
        didSet { UserDefaults.standard.set(kinopoiskUsername, forKey: "kinopoisk_username") }
    }
    @Published var imdbUsername: String {
        didSet { UserDefaults.standard.set(imdbUsername, forKey: "imdb_username") }
    }

    var hasAnyPlatform: Bool { !letterboxdUsername.isEmpty || kinopoiskConnected || imdbConnected }
    var connectedCount: Int {
        var c = 0
        if !letterboxdUsername.isEmpty { c += 1 }
        if kinopoiskConnected { c += 1 }
        if imdbConnected { c += 1 }
        return c
    }

    var connectedPlatformNames: [String] {
        var r: [String] = []
        if !letterboxdUsername.isEmpty { r.append("Letterboxd") }
        if kinopoiskConnected { r.append("Кинопоиск") }
        if imdbConnected { r.append("IMDB") }
        return r
    }

    init() {
        letterboxdUsername = UserDefaults.standard.string(forKey: "letterboxd_username") ?? ""
        kinopoiskConnected = UserDefaults.standard.bool(forKey: "kinopoisk_connected")
        imdbConnected = UserDefaults.standard.bool(forKey: "imdb_connected")
        kinopoiskUsername = UserDefaults.standard.string(forKey: "kinopoisk_username") ?? ""
        imdbUsername = UserDefaults.standard.string(forKey: "imdb_username") ?? ""
    }

    func connectLetterboxd(_ username: String) { letterboxdUsername = username }

    func disconnect() {
        letterboxdUsername = ""
        kinopoiskConnected = false
        imdbConnected = false
        kinopoiskUsername = ""
        imdbUsername = ""
    }
}

// MARK: - CinemaTab
enum CinemaTab: Int, CaseIterable {
    case activity = 0, watched, watchlist, explore

    var icon: String {
        switch self {
        case .activity: return "bolt.fill"
        case .watched: return "checkmark.circle.fill"
        case .watchlist: return "bookmark.fill"
        case .explore: return "safari.fill"
        }
    }

    var label: String {
        switch self {
        case .activity: return "Активность"
        case .watched: return "Просмотрено"
        case .watchlist: return "Буду смотреть"
        case .explore: return "Рекомендации"
        }
    }
}

// MARK: - View Model
@MainActor
class CinemaViewModel: ObservableObject {
    @Published var trending: [MovieResponse] = []
    @Published var myMovies: [MovieResponse] = []
    @Published var searchResults: [MovieResponse] = []
    @Published var isLoadingTrending = false
    @Published var isSearching = false
    @Published var error: AppError?

    private var searchTask: Task<Void, Never>?

    var watched: [MovieResponse] { myMovies.filter { $0.watched == true } }
    var watchlist: [MovieResponse] { myMovies.filter { $0.watched == false } }
    var recentlyWatched: [MovieResponse] { Array(watched.prefix(6)) }

    var uniqueTrending: [MovieResponse] {
        var seenIds = Set<Int>()
        var seenTitles = Set<String>()
        return trending.filter { movie in
            let id = movie.tmdb_id ?? movie.id ?? 0
            let title = movie.title.lowercased().trimmingCharacters(in: .whitespaces)
            // Дедупликация по ID и по названию
            if id != 0 && !seenIds.insert(id).inserted { return false }
            if !seenTitles.insert(title).inserted { return false }
            return id != 0
        }
    }

    func loadAll() async {
        isLoadingTrending = true
        async let t = NetworkManager.shared.getTrending()
        async let m = NetworkManager.shared.getMyMovies()
        trending = (try? await t) ?? []
        do {
            let fetched = try await m
            myMovies = fetched
            print("[Cinema] myMovies загружено: \(fetched.count), watched: \(watched.count), watchlist: \(watchlist.count)")
        } catch {
            print("[Cinema] ❌ getMyMovies ошибка: \(error)")
        }
        isLoadingTrending = false
    }

    func search(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []; isSearching = false; return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do {
                searchResults = try await NetworkManager.shared.searchMovies(query: trimmed)
            } catch {
                guard !Task.isCancelled else { return }
                self.error = AppError(error)
                searchResults = []
            }
            isSearching = false
        }
    }

    func cancelSearch() {
        searchTask?.cancel(); searchTask = nil
        searchResults = []; isSearching = false
    }

    func markWatched(tmdbId: Int) async {
        let _ = try? await NetworkManager.shared.markWatched(tmdbId: tmdbId)
        if let idx = myMovies.firstIndex(where: { $0.tmdb_id == tmdbId || $0.id == tmdbId }) {
            let old = myMovies[idx]
            myMovies[idx] = MovieResponse(id: old.id, tmdb_id: old.tmdb_id, title: old.title,
                                          year: old.year, rating: old.rating, poster_url: old.poster_url,
                                          watched: true, review: old.review)
        } else {
            myMovies = (try? await NetworkManager.shared.getMyMovies()) ?? myMovies
        }
    }

    func addToWatchlist(tmdbId: Int) async {
        let _ = try? await NetworkManager.shared.addToWatchlist(tmdbId: tmdbId)
        myMovies = (try? await NetworkManager.shared.getMyMovies()) ?? myMovies
    }

    func syncLetterboxdAndReload() async {
        await LetterboxdSyncService.shared.syncLetterboxd()
        // Всегда перезагружаем после синка — фильмы могли быть засинчены ранее
        if CinemaStorage.shared.hasAnyPlatform {
            do {
                let fetched = try await NetworkManager.shared.getMyMovies()
                myMovies = fetched
                print("[Cinema] После синка myMovies: \(fetched.count), watched: \(watched.count)")
            } catch {
                print("[Cinema] ❌ После синка getMyMovies ошибка: \(error)")
            }
        }
    }
}

// MARK: - Scroll Offset Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Main Cinema View
struct CinemaView: View {
    @StateObject private var vm = CinemaViewModel()
    @StateObject private var storage = CinemaStorage.shared
    @State private var selectedTab: CinemaTab = .activity
    @State private var searchQuery = ""
    @State private var isSearchFocused = false
    @State private var showPlatformSheet = false
    @State private var showHeader = true
    @State private var lastScrollOffset: CGFloat = 0
    @FocusState private var searchFieldFocused: Bool

    var showingSearch: Bool { isSearchFocused || !searchQuery.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Spacer for header
                    Color.clear
                        .frame(height: showingSearch ? 54 : (showHeader ? 104 : 0))
                        .animation(.easeInOut(duration: 0.25), value: showHeader)

                    if showingSearch {
                        CinemaSearchResultsView(vm: vm, searchQuery: searchQuery)
                            .transition(.opacity)
                    } else {
                        TabView(selection: $selectedTab) {
                            ActivityTabView(vm: vm, storage: storage,
                                            onShowPlatforms: { showPlatformSheet = true },
                                            onScroll: handleScroll)
                                .tag(CinemaTab.activity)
                            WatchedTabView(vm: vm, onScroll: handleScroll)
                                .tag(CinemaTab.watched)
                            WatchlistTabView(vm: vm, onScroll: handleScroll)
                                .tag(CinemaTab.watchlist)
                            ExploreTabView(vm: vm, onScroll: handleScroll)
                                .tag(CinemaTab.explore)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.spring(response: 0.3), value: selectedTab)
                    }
                }

                // Floating header
                VStack(spacing: 0) {
                    if !showingSearch && showHeader {
                        HStack(spacing: 0) {
                            CinemaIconTabBar(selectedTab: $selectedTab)
                            Spacer()
                            PlatformStatusDots(storage: storage) {
                                showPlatformSheet = true
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    CinemaSearchBar(
                        query: $searchQuery,
                        isSearchFocused: $isSearchFocused,
                        searchFieldFocused: $searchFieldFocused,
                        showingSearch: showingSearch,
                        onSearch: { vm.search(query: searchQuery) },
                        onCancel: {
                            searchQuery = ""
                            vm.cancelSearch()
                            isSearchFocused = false
                            searchFieldFocused = false
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    Rectangle()
                        .fill(Color(.separator).opacity(0.25))
                        .frame(height: 0.5)
                }
                .background(.ultraThinMaterial)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPlatformSheet) {
                PlatformConnectSheet()
            }
            .errorAlert($vm.error)
            .task {
                await vm.loadAll()
                await vm.syncLetterboxdAndReload()
            }
            .refreshable {
                await vm.loadAll()
                await vm.syncLetterboxdAndReload()
            }
        }
        .animation(.spring(response: 0.25), value: showingSearch)
        .animation(.easeInOut(duration: 0.25), value: showHeader)
    }

    private func handleScroll(_ offset: CGFloat) {
        let delta = offset - lastScrollOffset
        if offset <= 0 {
            if !showHeader { showHeader = true }
        } else if delta < -6 {
            if !showHeader { showHeader = true }
        } else if delta > 6 && offset > 60 {
            if showHeader { showHeader = false }
        }
        lastScrollOffset = offset
    }
}

// MARK: - Icon-Only Tab Bar
struct CinemaIconTabBar: View {
    @Binding var selectedTab: CinemaTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CinemaTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTab = tab
                    }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? .white : .secondary)
                        .frame(width: 38, height: 32)
                        .background {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color.primary.opacity(0.85))
                                    .matchedGeometryEffect(id: "ctab", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(.systemGray5).opacity(0.7))
        .clipShape(Capsule())
    }
}

// MARK: - Platform Status Dots
struct PlatformStatusDots: View {
    @ObservedObject var storage: CinemaStorage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                HStack(spacing: -3) {
                    PlatformDot(platform: "letterboxd", active: !storage.letterboxdUsername.isEmpty)
                    PlatformDot(platform: "kinopoisk", active: storage.kinopoiskConnected)
                    PlatformDot(platform: "imdb", active: storage.imdbConnected)
                }

                if storage.hasAnyPlatform {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(storage.hasAnyPlatform ? Color.green.opacity(0.06) : Color.blue.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .stroke(storage.hasAnyPlatform ? Color.green.opacity(0.12) : Color.blue.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlatformDot: View {
    let platform: String
    let active: Bool
    var color: Color {
        switch platform {
        case "letterboxd": return Color(red: 0, green: 0.75, blue: 0.4)
        case "kinopoisk": return .orange
        case "imdb": return Color(red: 0.9, green: 0.75, blue: 0.0)
        default: return .gray
        }
    }
    var body: some View {
        Circle()
            .fill(active ? color : Color(.systemGray4).opacity(0.4))
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
    }
}

// MARK: - Cinema Search Bar
struct CinemaSearchBar: View {
    @Binding var query: String
    @Binding var isSearchFocused: Bool
    var searchFieldFocused: FocusState<Bool>.Binding
    let showingSearch: Bool
    let onSearch: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Найти фильм...", text: $query)
                    .focused(searchFieldFocused)
                    .onSubmit(onSearch)
                    .submitLabel(.search)
                    .font(.subheadline)
                    .onChange(of: query) { _ in onSearch() }
                    .onChange(of: searchFieldFocused.wrappedValue) { focused in
                        withAnimation(.spring(response: 0.3)) { isSearchFocused = focused }
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14)).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            if showingSearch {
                Button("Отмена") {
                    withAnimation(.spring(response: 0.3)) { onCancel() }
                }
                .font(.subheadline).foregroundStyle(.blue)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Search Results
struct CinemaSearchResultsView: View {
    @ObservedObject var vm: CinemaViewModel
    let searchQuery: String

    var body: some View {
        Group {
            if vm.isSearching {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Ищем «\(searchQuery)»...")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.searchResults.isEmpty && !searchQuery.isEmpty {
                ContentUnavailableView.search(text: searchQuery)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.searchResults.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(.quaternary)
                    Text("Введи название")
                        .font(.subheadline).foregroundStyle(.tertiary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.searchResults) { movie in
                            NavigationLink(destination: MovieDetailView(
                                tmdbId: movie.stableId, title: movie.title,
                                isWatched: movie.watched == true, vm: vm
                            )) {
                                SearchRow(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct SearchRow: View {
    let movie: MovieResponse
    var body: some View {
        HStack(spacing: 14) {
            CinemaPoster(url: movie.poster_url, width: 50, height: 72)
            VStack(alignment: .leading, spacing: 5) {
                Text(movie.title)
                    .font(.subheadline).fontWeight(.medium).lineLimit(2)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    if let y = movie.year {
                        Text(y).font(.caption).foregroundStyle(.secondary)
                    }
                    if let r = movie.rating, r > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                            Text(String(format: "%.1f", r)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if movie.watched == true {
                    Text("Просмотрено")
                        .font(.caption2).fontWeight(.medium).foregroundStyle(.green)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - Activity Tab
struct ActivityTabView: View {
    @ObservedObject var vm: CinemaViewModel
    @ObservedObject var storage: CinemaStorage
    @ObservedObject var syncService = LetterboxdSyncService.shared
    let onShowPlatforms: () -> Void
    let onScroll: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                                           value: -geo.frame(in: .named("actscroll")).minY)
                }
                .frame(height: 0)

                if vm.isLoadingTrending && vm.watched.isEmpty {
                    LoadingPulse().padding(.top, 80)
                } else {
                    // Nudge to connect
                    if !storage.hasAnyPlatform {
                        ConnectNudge(onConnect: onShowPlatforms)
                            .padding(.horizontal, 16)
                            .padding(.top, 16).padding(.bottom, 8)
                    }

                    // Sync banner
                    if storage.hasAnyPlatform {
                        SyncBanner(syncService: syncService, storage: storage)
                            .padding(.horizontal, 16)
                            .padding(.top, 12).padding(.bottom, 4)
                    }

                    // Title
                    if !vm.watched.isEmpty {
                        Text("Твоя активность")
                            .font(.title3).fontWeight(.bold)
                            .padding(.horizontal, 16)
                            .padding(.top, 20).padding(.bottom, 4)
                    }

                    // Activity cards
                    if vm.watched.isEmpty {
                        EmptyActivityView().padding(.top, 40)
                    } else {
                        ForEach(vm.watched) { movie in
                            NavigationLink(destination: MovieDetailView(
                                tmdbId: movie.stableId, title: movie.title,
                                isWatched: true, vm: vm
                            )) {
                                ActivityCard(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Insight card
                    if vm.watched.count >= 2 {
                        InsightCard(watchedCount: vm.watched.count)
                            .padding(.horizontal, 16).padding(.top, 12)
                    }

                    // Quiz nudge
                    if let random = vm.watched.randomElement() {
                        QuizNudge(movie: random)
                            .padding(.horizontal, 16).padding(.top, 12)
                    }

                    // Trending peek
                    if !vm.uniqueTrending.isEmpty {
                        TrendingPeek(movies: Array(vm.uniqueTrending.prefix(8)), vm: vm)
                            .padding(.top, 24)
                    }

                    Spacer(minLength: 80)
                }
            }
            .coordinateSpace(name: "actscroll")
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { onScroll($0) }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Watched Tab
struct WatchedTabView: View {
    @ObservedObject var vm: CinemaViewModel
    let onScroll: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                GeometryReader { geo in
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                                           value: -geo.frame(in: .named("wscroll")).minY)
                }
                .frame(height: 0)

                if vm.watched.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(.quaternary)
                        Text("Пока нет просмотренных")
                            .font(.subheadline).foregroundStyle(.tertiary)
                        Text("Найди фильм через поиск\nили подключи платформу")
                            .font(.caption).foregroundStyle(.quaternary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 100)
                } else {
                    // Stats
                    HStack(spacing: 0) {
                        WatchedStat(value: "\(vm.watched.count)", label: "фильмов", icon: "film.fill", color: .blue)
                        WatchedStat(value: "~\(vm.watched.count * 12)", label: "слов", icon: "textformat.abc", color: .orange)
                        WatchedStat(value: "\(vm.watched.count)", label: "уроков", icon: "book.fill", color: .green)
                    }
                    .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 12)

                    // Poster grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ], spacing: 14) {
                        ForEach(vm.watched) { movie in
                            NavigationLink(destination: MovieDetailView(
                                tmdbId: movie.stableId, title: movie.title,
                                isWatched: true, vm: vm
                            )) {
                                WatchedPosterCell(movie: movie)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 80)
                }
            }
            .coordinateSpace(name: "wscroll")
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { onScroll($0) }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Watchlist Tab
struct WatchlistTabView: View {
    @ObservedObject var vm: CinemaViewModel
    let onScroll: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                GeometryReader { geo in
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                                           value: -geo.frame(in: .named("wlscroll")).minY)
                }
                .frame(height: 0)

                if vm.watchlist.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(.quaternary)
                        Text("Список пуст")
                            .font(.subheadline).foregroundStyle(.tertiary)
                        Text("Добавляй фильмы через поиск")
                            .font(.caption).foregroundStyle(.quaternary)
                    }
                    .padding(.top, 100)
                } else {
                    ForEach(vm.watchlist) { movie in
                        NavigationLink(destination: MovieDetailView(
                            tmdbId: movie.stableId, title: movie.title,
                            isWatched: false, vm: vm
                        )) {
                            WatchlistRow(movie: movie)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 80)
                }
            }
            .coordinateSpace(name: "wlscroll")
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { onScroll($0) }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Explore Tab
struct ExploreTabView: View {
    @ObservedObject var vm: CinemaViewModel
    let onScroll: (CGFloat) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self,
                                           value: -geo.frame(in: .named("escroll")).minY)
                }
                .frame(height: 0)

                if vm.isLoadingTrending && vm.uniqueTrending.isEmpty {
                    LoadingPulse().padding(.top, 80)
                } else if vm.uniqueTrending.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "safari")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(.quaternary)
                        Text("Нет рекомендаций")
                            .font(.subheadline).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 100)
                } else {
                    // Hero card
                    if let hero = vm.uniqueTrending.first {
                        HeroCard(movie: hero, vm: vm)
                            .padding(.horizontal, 16).padding(.top, 12)
                    }

                    Text("В тренде")
                        .font(.title3).fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.top, 24).padding(.bottom, 8)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 16) {
                        ForEach(Array(vm.uniqueTrending.dropFirst().enumerated()), id: \.element.stableId) { i, movie in
                            NavigationLink(destination: MovieDetailView(
                                tmdbId: movie.stableId, title: movie.title,
                                isWatched: movie.watched == true, vm: vm
                            )) {
                                ExplorePoster(movie: movie, rank: i + 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 80)
                }
            }
            .coordinateSpace(name: "escroll")
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { onScroll($0) }
        .background(Color(.systemGroupedBackground))
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Components
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// MARK: Activity Card
struct ActivityCard: View {
    let movie: MovieResponse
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                CinemaPoster(url: movie.poster_url, width: 54, height: 78)
                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .lineLimit(2).foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        if let y = movie.year {
                            Text(y).font(.caption).foregroundStyle(.secondary)
                        }
                        if let r = movie.rating, r > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                                Text(String(format: "%.1f", r)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        Chip(icon: "text.book.closed.fill", text: "Урок", color: .blue)
                        Chip(icon: "gamecontroller.fill", text: "Квиз", color: .orange)
                        Chip(icon: "square.and.arrow.up", text: "Anki", color: .purple)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2).foregroundStyle(.quaternary)
            }
            .padding(14)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16).padding(.vertical, 5)
    }
}

struct Chip: View {
    let icon: String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .semibold))
            Text(text).font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: Connect Nudge
struct ConnectNudge: View {
    let onConnect: () -> Void
    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Подключи платформу")
                        .font(.subheadline).fontWeight(.semibold).foregroundStyle(.primary)
                    Text("Letterboxd · Кинопоиск · IMDB")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Sync Banner
struct SyncBanner: View {
    @ObservedObject var syncService: LetterboxdSyncService
    @ObservedObject var storage: CinemaStorage
    var body: some View {
        HStack(spacing: 10) {
            if syncService.isSyncing {
                ProgressView().scaleEffect(0.6).frame(width: 16, height: 16)
                Text("Синхронизация...")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let error = syncService.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.orange)
                Text(error).font(.caption2).foregroundStyle(.orange).lineLimit(1)
            } else {
                HStack(spacing: -3) {
                    ForEach(storage.connectedPlatformNames, id: \.self) { name in
                        SyncDot(name: name)
                    }
                }
                if let date = syncService.lastSyncDate {
                    let f = RelativeDateTimeFormatter()
                    Text("Обновлено \(f.localizedString(for: date, relativeTo: Date()))")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("\(storage.connectedCount) подключено")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !syncService.isSyncing {
                Button {
                    Task { await syncService.syncLetterboxd() }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.6))
        .clipShape(Capsule())
    }
}

struct SyncDot: View {
    let name: String
    var color: Color {
        switch name {
        case "Letterboxd": return Color(red: 0, green: 0.75, blue: 0.4)
        case "Кинопоиск": return .orange
        case "IMDB": return Color(red: 0.9, green: 0.75, blue: 0.0)
        default: return .gray
        }
    }
    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1))
    }
}

// MARK: Empty Activity
struct EmptyActivityView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "popcorn")
                .font(.system(size: 48, weight: .thin)).foregroundStyle(.quaternary)
            Text("Тут будет твоя активность")
                .font(.subheadline).foregroundStyle(.tertiary)
            Text("Посмотри фильм и он появится здесь")
                .font(.caption).foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Insight Card
struct InsightCard: View {
    let watchedCount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.indigo)
                Text("Твоя статистика")
                    .font(.subheadline).fontWeight(.bold)
            }
            HStack(spacing: 0) {
                CinemaStatCell(value: "\(watchedCount)", label: "фильмов", color: .blue)
                CinemaStatCell(value: "~\(watchedCount * 12)", label: "слов", color: .orange)
                CinemaStatCell(value: "\(watchedCount)", label: "уроков", color: .green)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

struct CinemaStatCell: View {
    let value: String; let label: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Quiz Nudge
struct QuizNudge: View {
    let movie: MovieResponse
    var body: some View {
        NavigationLink(destination: MovieQuizView(movie: movie)) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [.orange, .pink],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Квиз по «\(movie.title)»")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary).lineLimit(1)
                    Text("Проверь слова из фильма")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.caption).foregroundStyle(.white)
                    .padding(8).background(Color.orange).clipShape(Circle())
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Trending Peek
struct TrendingPeek: View {
    let movies: [MovieResponse]
    let vm: CinemaViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Может заинтересовать")
                .font(.subheadline).fontWeight(.bold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(movies) { movie in
                        NavigationLink(destination: MovieDetailView(
                            tmdbId: movie.stableId, title: movie.title,
                            isWatched: movie.watched == true, vm: vm
                        )) {
                            PeekCard(movie: movie)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct PeekCard: View {
    let movie: MovieResponse
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                CinemaPoster(url: movie.poster_url, width: 120, height: 170)
                if let r = movie.rating, r > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                        Text(String(format: "%.1f", r))
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(5)
                }
            }
            Text(movie.title)
                .font(.caption).fontWeight(.medium)
                .lineLimit(2).frame(width: 120, alignment: .leading)
            if let y = movie.year {
                Text(y).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Watched Stats
struct WatchedStat: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: Watched Poster Cell
struct WatchedPosterCell: View {
    let movie: MovieResponse
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            CinemaPoster(url: movie.poster_url, width: .infinity, height: 155)
            Text(movie.title)
                .font(.caption2).fontWeight(.medium).lineLimit(2).foregroundStyle(.primary)
            HStack(spacing: 4) {
                if let y = movie.year {
                    Text(y).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                if let r = movie.rating, r > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(.yellow)
                        Text(String(format: "%.1f", r)).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: Watchlist Row
struct WatchlistRow: View {
    let movie: MovieResponse
    var body: some View {
        HStack(spacing: 14) {
            CinemaPoster(url: movie.poster_url, width: 48, height: 68)
            VStack(alignment: .leading, spacing: 5) {
                Text(movie.title)
                    .font(.subheadline).fontWeight(.medium).lineLimit(2)
                HStack(spacing: 6) {
                    if let y = movie.year {
                        Text(y).font(.caption).foregroundStyle(.secondary)
                    }
                    if let r = movie.rating, r > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                            Text(String(format: "%.1f", r)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "bookmark.fill")
                .font(.caption).foregroundStyle(.blue.opacity(0.4))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: Hero Card
struct HeroCard: View {
    let movie: MovieResponse
    let vm: CinemaViewModel
    var body: some View {
        NavigationLink(destination: MovieDetailView(
            tmdbId: movie.stableId, title: movie.title,
            isWatched: movie.watched == true, vm: vm
        )) {
            ZStack(alignment: .bottomLeading) {
                if let url = movie.poster_url, let u = URL(string: url) {
                    AsyncImage(url: u) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                    .frame(maxWidth: .infinity).frame(height: 280).clipped()
                }
                LinearGradient(colors: [.clear, .clear, .black.opacity(0.8)],
                               startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 8) {
                    Text("#1 В ТРЕНДЕ")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(1.5)
                    Text(movie.title)
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(.white).lineLimit(2)
                    HStack(spacing: 10) {
                        if let y = movie.year {
                            Text(y).font(.caption).foregroundStyle(.white.opacity(0.7))
                        }
                        if let r = movie.rating, r > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                                Text(String(format: "%.1f", r)).font(.caption).fontWeight(.medium).foregroundStyle(.white)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Explore Poster
struct ExplorePoster: View {
    let movie: MovieResponse
    let rank: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                CinemaPoster(url: movie.poster_url, width: .infinity, height: 220)
                Text("\(rank)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .padding(8)
            }
            Text(movie.title)
                .font(.caption).fontWeight(.medium).lineLimit(2)
            HStack(spacing: 4) {
                if let y = movie.year { Text(y).font(.caption2).foregroundStyle(.secondary) }
                if let r = movie.rating, r > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(.yellow)
                        Text(String(format: "%.1f", r)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Reusable Poster
struct CinemaPoster: View {
    let url: String?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if let url = url, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray5)
                }
            } else {
                Color(.systemGray5)
                    .overlay(Image(systemName: "film").font(.caption).foregroundStyle(.quaternary))
            }
        }
        .frame(maxWidth: width == .infinity ? .infinity : width)
        .frame(width: width == .infinity ? nil : width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Loading Pulse
struct LoadingPulse: View {
    @State private var animate = false
    var body: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
                .scaleEffect(animate ? 1.1 : 0.9)
                .opacity(animate ? 0.5 : 1)
            Text("Загружаем...")
                .font(.subheadline).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Compat
struct CinemaSectionHeader: View {
    let title: String; let icon: String; let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            Text(title).font(.headline)
        }
    }
}

struct MovieListRow: View {
    let movie: MovieResponse
    var body: some View {
        HStack(spacing: 12) {
            CinemaPoster(url: movie.poster_url, width: 44, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title).font(.subheadline).fontWeight(.medium).lineLimit(2)
                HStack(spacing: 8) {
                    if let year = movie.year { Text(year).font(.caption).foregroundStyle(.secondary) }
                    if let rating = movie.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            Text(String(format: "%.1f", rating)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if movie.watched == true {
                    Text("Просмотрено").font(.caption2).foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
