import SwiftUI

struct PlatformConnectSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storage = CinemaStorage.shared
    @State private var letterboxdInput = ""
    @State private var kinopoiskInput = ""
    @State private var imdbInput = ""
    @State private var expandedPlatform: String?
    @State private var isLoading = false
    @State private var successPlatform = ""
    @State private var animateIn = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        HStack(spacing: -6) {
                            PlatformOrb(color: Color(red: 0, green: 0.75, blue: 0.4), icon: "film", delay: 0)
                            PlatformOrb(color: .orange, icon: "star", delay: 0.1)
                            PlatformOrb(color: Color(red: 0.9, green: 0.75, blue: 0.0), icon: "play", delay: 0.2)
                        }
                        .scaleEffect(animateIn ? 1 : 0.6)
                        .opacity(animateIn ? 1 : 0)

                        Text("Платформы")
                            .font(.title2).fontWeight(.bold)
                        Text("Отмечай просмотренные фильмы где удобно —\nAURA создаст уроки автоматически")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { animateIn = true }
                    }

                    // Platform cards
                    VStack(spacing: 12) {
                        // Letterboxd
                        PlatformCard(
                            name: "Letterboxd",
                            desc: "Оценки, списки и рецензии",
                            color: Color(red: 0, green: 0.75, blue: 0.4),
                            icon: "film.fill",
                            isConnected: !storage.letterboxdUsername.isEmpty,
                            detail: storage.letterboxdUsername.isEmpty ? nil : "@\(storage.letterboxdUsername)",
                            isExpanded: expandedPlatform == "letterboxd",
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    expandedPlatform = expandedPlatform == "letterboxd" ? nil : "letterboxd"
                                }
                            },
                            onDisconnect: !storage.letterboxdUsername.isEmpty ? {
                                withAnimation { storage.letterboxdUsername = "" }
                            } : nil
                        )

                        // Letterboxd input
                        if expandedPlatform == "letterboxd" && storage.letterboxdUsername.isEmpty {
                            UsernameInput(
                                prefix: "letterboxd.com/",
                                text: $letterboxdInput,
                                color: Color(red: 0, green: 0.75, blue: 0.4),
                                isLoading: isLoading
                            ) {
                                connectPlatform("letterboxd")
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // Kinopoisk
                        PlatformCard(
                            name: "Кинопоиск",
                            desc: "Оценки и коллекции",
                            color: .orange,
                            icon: "star.circle.fill",
                            isConnected: storage.kinopoiskConnected,
                            detail: storage.kinopoiskConnected ? (storage.kinopoiskUsername.isEmpty ? "Подключён" : "@\(storage.kinopoiskUsername)") : nil,
                            isExpanded: expandedPlatform == "kinopoisk",
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    if storage.kinopoiskConnected {
                                        expandedPlatform = nil
                                    } else {
                                        expandedPlatform = expandedPlatform == "kinopoisk" ? nil : "kinopoisk"
                                    }
                                }
                            },
                            onDisconnect: storage.kinopoiskConnected ? {
                                withAnimation {
                                    storage.kinopoiskConnected = false
                                    storage.kinopoiskUsername = ""
                                }
                            } : nil
                        )

                        // Kinopoisk input
                        if expandedPlatform == "kinopoisk" && !storage.kinopoiskConnected {
                            UsernameInput(
                                prefix: "kinopoisk.ru/user/",
                                text: $kinopoiskInput,
                                color: .orange,
                                isLoading: isLoading
                            ) {
                                connectPlatform("kinopoisk")
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }

                        // IMDB
                        PlatformCard(
                            name: "IMDB",
                            desc: "Рейтинги и watchlist",
                            color: Color(red: 0.9, green: 0.75, blue: 0.0),
                            icon: "play.rectangle.fill",
                            isConnected: storage.imdbConnected,
                            detail: storage.imdbConnected ? (storage.imdbUsername.isEmpty ? "Подключён" : "@\(storage.imdbUsername)") : nil,
                            isExpanded: expandedPlatform == "imdb",
                            onTap: {
                                withAnimation(.spring(response: 0.3)) {
                                    if storage.imdbConnected {
                                        expandedPlatform = nil
                                    } else {
                                        expandedPlatform = expandedPlatform == "imdb" ? nil : "imdb"
                                    }
                                }
                            },
                            onDisconnect: storage.imdbConnected ? {
                                withAnimation {
                                    storage.imdbConnected = false
                                    storage.imdbUsername = ""
                                }
                            } : nil
                        )

                        // IMDB input
                        if expandedPlatform == "imdb" && !storage.imdbConnected {
                            UsernameInput(
                                prefix: "imdb.com/user/",
                                text: $imdbInput,
                                color: Color(red: 0.9, green: 0.75, blue: 0.0),
                                isLoading: isLoading
                            ) {
                                connectPlatform("imdb")
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.horizontal, 16)

                    // What you get
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Что даёт подключение")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        VStack(spacing: 10) {
                            BenefitRow(icon: "bell.badge.fill", color: .blue,
                                       text: "Мгновенные уроки после каждого просмотра")
                            BenefitRow(icon: "text.book.closed.fill", color: .purple,
                                       text: "Слова, идиомы и сленг из каждого фильма")
                            BenefitRow(icon: "person.crop.rectangle.stack.fill", color: .orange,
                                       text: "Словарь персонажа — жаргон и манера речи героев")
                            BenefitRow(icon: "square.and.arrow.up.fill", color: .green,
                                       text: "Экспорт в Anki одним нажатием")
                        }
                    }
                    .padding(.horizontal, 20)

                    // Success
                    if !successPlatform.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("\(successPlatform) подключён")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.green.opacity(0.06))
                        .clipShape(Capsule())
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Disconnect all
                    if storage.hasAnyPlatform {
                        Button(role: .destructive) {
                            withAnimation {
                                storage.disconnect()
                                successPlatform = ""
                                expandedPlatform = nil
                            }
                        } label: {
                            Text("Отключить все")
                                .font(.subheadline).foregroundStyle(.red.opacity(0.7))
                        }
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Платформы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func connectPlatform(_ platform: String) {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            switch platform {
            case "letterboxd":
                let u = letterboxdInput.trimmingCharacters(in: .whitespaces)
                guard !u.isEmpty else { isLoading = false; return }
                storage.connectLetterboxd(u)
            case "kinopoisk":
                let u = kinopoiskInput.trimmingCharacters(in: .whitespaces)
                storage.kinopoiskUsername = u
                storage.kinopoiskConnected = true
            case "imdb":
                let u = imdbInput.trimmingCharacters(in: .whitespaces)
                storage.imdbUsername = u
                storage.imdbConnected = true
            default: break
            }
            isLoading = false
            expandedPlatform = nil
            withAnimation(.spring(response: 0.4)) {
                successPlatform = platform == "kinopoisk" ? "Кинопоиск" :
                                  platform == "imdb" ? "IMDB" : "Letterboxd"
            }
        }
    }
}

// MARK: - Platform Orb
struct PlatformOrb: View {
    let color: Color
    let icon: String
    let delay: Double
    @State private var show = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 52, height: 52)
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
        }
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
        .scaleEffect(show ? 1 : 0.3)
        .opacity(show ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) { show = true }
        }
    }
}

// MARK: - Platform Card
struct PlatformCard: View {
    let name: String
    let desc: String
    let color: Color
    let icon: String
    let isConnected: Bool
    let detail: String?
    let isExpanded: Bool
    let onTap: () -> Void
    let onDisconnect: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name).font(.subheadline).fontWeight(.bold)
                    if isConnected {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption).foregroundStyle(color)
                    }
                }
                Text(desc).font(.caption).foregroundStyle(.secondary)
                if let d = detail {
                    Text(d).font(.caption2).fontWeight(.medium).foregroundStyle(color)
                }
            }

            Spacer()

            if isConnected {
                Menu {
                    if let disc = onDisconnect {
                        Button(role: .destructive) {
                            disc()
                        } label: {
                            Label("Отключить", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3).foregroundStyle(color)
                }
            } else {
                Button(action: onTap) {
                    Text(isExpanded ? "Скрыть" : "Подключить")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(color)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(color.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isConnected ? color.opacity(0.2) : (isExpanded ? color.opacity(0.15) : Color.clear), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Username Input
struct UsernameInput: View {
    let prefix: String
    @Binding var text: String
    let color: Color
    let isLoading: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Text(prefix)
                    .font(.subheadline).foregroundStyle(.secondary)
                TextField("username", text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.subheadline).fontWeight(.medium)
            }
            .padding(14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button(action: onSubmit) {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "link")
                        Text("Подключить")
                    }
                }
                .font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Benefit Row
struct BenefitRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }
}
