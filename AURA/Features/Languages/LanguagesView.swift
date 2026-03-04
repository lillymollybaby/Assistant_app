import SwiftUI

struct LanguagesView: View {
    @State private var streak: StreakResponse?
    @State private var vocab: [VocabResponse] = []
    @State private var selectedTab = 0
    @State private var showRoleplay = false

    let days = ["S", "F", "T", "W", "T", "M", "S"]
    let completed = [true, true, true, true, true, false, true]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: Streak Hero
                    LanguageHeroCard(streak: streak)
                        .padding(.horizontal)

                    // MARK: Tab
                    HStack(spacing: 0) {
                        ForEach(["Уроки", "Словарь", "Roleplay"], id: \.self) { tab in
                            let idx = ["Уроки", "Словарь", "Roleplay"].firstIndex(of: tab)!
                            Button {
                                withAnimation(.spring(response: 0.3)) { selectedTab = idx }
                            } label: {
                                Text(tab)
                                    .font(.subheadline)
                                    .fontWeight(selectedTab == idx ? .bold : .regular)
                                    .foregroundColor(selectedTab == idx ? .primary : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedTab == idx ? Color(.systemBackground) : Color.clear)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    if selectedTab == 0 {
                        LessonsTab(streak: streak)
                    } else if selectedTab == 1 {
                        VocabTab(vocab: vocab)
                    } else {
                        RoleplayTab()
                    }

                    Spacer(minLength: 30)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            if let v = try? await NetworkManager.shared.getVocabulary() { vocab = v }
            if let s: StreakResponse = try? await NetworkManager.shared.request("/languages/streak") { streak = s }
        }
    }
}

// MARK: - Language Config
struct LanguageConfig {
    let code: String
    let name: String
    let flag: String
    let levels: [String]

    static let all: [LanguageConfig] = [
        LanguageConfig(code: "German",   name: "German",   flag: "🇩🇪", levels: ["A1","A2","B1","B2","C1","C2"]),
        LanguageConfig(code: "English",  name: "English",  flag: "🇬🇧", levels: ["A1","A2","B1","B2","C1","C2"]),
        LanguageConfig(code: "French",   name: "French",   flag: "🇫🇷", levels: ["A1","A2","B1","B2","C1","C2"]),
        LanguageConfig(code: "Spanish",  name: "Spanish",  flag: "🇪🇸", levels: ["A1","A2","B1","B2","C1","C2"]),
        LanguageConfig(code: "Italian",  name: "Italian",  flag: "🇮🇹", levels: ["A1","A2","B1","B2","C1","C2"]),
        LanguageConfig(code: "Japanese", name: "Japanese", flag: "🇯🇵", levels: ["N5","N4","N3","N2","N1"]),
        LanguageConfig(code: "Chinese",  name: "Chinese",  flag: "🇨🇳", levels: ["HSK1","HSK2","HSK3","HSK4","HSK5"]),
        LanguageConfig(code: "Korean",   name: "Korean",   flag: "🇰🇷", levels: ["TOPIK1","TOPIK2","TOPIK3"]),
    ]

    static func find(_ code: String) -> LanguageConfig {
        all.first { $0.code == code } ?? all[0]
    }
}

// MARK: - Hero Card
struct LanguageHeroCard: View {
    let streak: StreakResponse?
    @ObservedObject private var settings = ProfileSettings.shared

    var lang: LanguageConfig { LanguageConfig.find(settings.learningLanguage) }

    var body: some View {
        HStack(spacing: 16) {
            Text(lang.flag).font(.system(size: 44))

            VStack(alignment: .leading, spacing: 4) {
                Text(lang.name).font(.title2).bold()
                HStack(spacing: 6) {
                    Text("B1").font(.caption).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15)).foregroundColor(.blue).cornerRadius(4)
                    Text("Intermediate").font(.subheadline).foregroundColor(.secondary)
                }
                ProgressView(value: Double(streak?.progress_percent ?? 0), total: 100)
                    .tint(.blue)
                    .frame(width: 140)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(.orange)
                    Text("\(streak?.streak_days ?? 0)").font(.title2).bold()
                }
                Text("дней подряд").font(.caption2).foregroundColor(.secondary)
                Text("\(streak?.learned_words ?? 0) слов").font(.caption2).foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Lessons Tab
struct LessonsTab: View {
    let streak: StreakResponse?

    var body: some View {
        VStack(spacing: 14) {
            // Weekly calendar
            VStack(alignment: .leading, spacing: 12) {
                Text("Эта неделя").font(.headline)
                HStack(spacing: 6) {
                    ForEach(0..<7) { i in
                        let days = ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
                        let done = [true, true, true, true, false, false, false]
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(done[i] ? Color.blue : Color(.systemGray5))
                                    .frame(width: 34, height: 34)
                                if done[i] {
                                    Image(systemName: "checkmark").font(.caption2).bold().foregroundColor(.white)
                                }
                            }
                            Text(days[i]).font(.caption2).foregroundColor(.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            .padding(.horizontal)

            // Smart Lessons
            VStack(alignment: .leading, spacing: 12) {
                Text("Умные уроки").font(.headline)

                LessonCard(
                    icon: "stethoscope",
                    iconColor: .red,
                    title: "At the Dentist",
                    subtitle: "Связано с твоим расписанием",
                    tag: "Logistics",
                    tagColor: .blue,
                    isNew: true,
                    xp: 50
                )
                LessonCard(
                    icon: "film.fill",
                    iconColor: .purple,
                    title: "Film Dialogue",
                    subtitle: "Слова из последнего фильма Cinema",
                    tag: "Cinema",
                    tagColor: .purple,
                    isNew: true,
                    xp: 40
                )
                LessonCard(
                    icon: "fork.knife",
                    iconColor: .orange,
                    title: "Restaurant Phrases",
                    subtitle: "Полезно для Food логов",
                    tag: "Food",
                    tagColor: .orange,
                    isNew: false,
                    xp: 30
                )
                LessonCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: .green,
                    title: "Small Talk",
                    subtitle: "Повседневные разговоры",
                    tag: "Daily",
                    tagColor: .green,
                    isNew: false,
                    xp: 25
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            .padding(.horizontal)
        }
    }
}

struct LessonCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let tag: String
    let tagColor: Color
    let isNew: Bool
    let xp: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon).foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.subheadline).fontWeight(.semibold)
                    if isNew {
                        Text("NEW").font(.caption2).bold().foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.blue).cornerRadius(4)
                    }
                }
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("+\(xp) XP").font(.caption2).bold().foregroundColor(.yellow)
                HStack(spacing: 4) {
                    Text(tag).font(.caption2).foregroundColor(tagColor)
                    Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(
            Rectangle()
                .fill(iconColor)
                .frame(width: 3)
                .padding(.vertical, 6),
            alignment: .leading
        )
        .padding(.leading, 8)
    }
}

// MARK: - Vocab Tab
struct VocabTab: View {
    let vocab: [VocabResponse]
    @State private var searchQuery = ""

    var filtered: [VocabResponse] {
        if searchQuery.isEmpty { return vocab }
        return vocab.filter { $0.word.lowercased().contains(searchQuery.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 14) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Поиск слов...", text: $searchQuery)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            .padding(.horizontal)

            // Stats
            HStack(spacing: 12) {
                VocabStatBadge(value: "\(vocab.filter { $0.learned }.count)", label: "Выучено", color: .green)
                VocabStatBadge(value: "\(vocab.filter { !$0.learned }.count)", label: "В процессе", color: .orange)
                VocabStatBadge(value: "\(vocab.count)", label: "Всего", color: .blue)
            }
            .padding(.horizontal)

            // Word list
            if vocab.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical").font(.system(size: 40)).foregroundColor(.secondary.opacity(0.4))
                    Text("Словарь пуст").font(.subheadline).foregroundColor(.secondary)
                    Text("Слова добавляются из уроков и Cinema").font(.caption).foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, word in
                        VocabWordRow(word: word)
                        if idx < filtered.count - 1 { Divider().padding(.leading, 56) }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                .padding(.horizontal)
            }
        }
    }
}

struct VocabStatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).bold().foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(14)
    }
}

struct VocabWordRow: View {
    let word: VocabResponse
    @State private var showExample = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(word.learned ? Color.green.opacity(0.12) : Color.blue.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: word.learned ? "checkmark" : "book.fill")
                        .font(.caption)
                        .foregroundColor(word.learned ? .green : .blue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(word.word).font(.subheadline).fontWeight(.semibold)
                    Text(word.translation).font(.caption).foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) { showExample.toggle() }
                } label: {
                    Image(systemName: showExample ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding()

            if showExample, let example = word.example, !example.isEmpty {
                Text("💬 \(example)")
                    .font(.caption).italic().foregroundColor(.blue)
                    .padding(.horizontal).padding(.bottom, 10).padding(.leading, 52)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Roleplay Tab
struct RoleplayTab: View {
    let scenarios: [RoleplayScenario] = [
        RoleplayScenario(emoji: "🏥", title: "At the Doctor", description: "Опиши симптомы, запишись на приём", level: "B1", tag: "Logistics", tagColor: .red, messages: 12),
        RoleplayScenario(emoji: "🎬", title: "Movie Discussion", description: "Обсуди последний фильм с другом", level: "B1", tag: "Cinema", tagColor: .purple, messages: 8),
        RoleplayScenario(emoji: "🍽️", title: "At the Restaurant", description: "Сделай заказ, спроси о блюдах", level: "A2", tag: "Food", tagColor: .orange, messages: 10),
        RoleplayScenario(emoji: "✈️", title: "At the Airport", description: "Регистрация, посадка, таможня", level: "B2", tag: "Travel", tagColor: .blue, messages: 15),
        RoleplayScenario(emoji: "🏠", title: "Renting an Apartment", description: "Переговоры с арендодателем", level: "B2", tag: "Daily", tagColor: .green, messages: 14),
        RoleplayScenario(emoji: "💼", title: "Job Interview", description: "Расскажи о себе и опыте", level: "C1", tag: "Career", tagColor: .indigo, messages: 18),
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill").foregroundColor(.green)
                    Text("AI Roleplay").font(.headline)
                    Spacer()
                    Text("Powered by Gemini").font(.caption2).foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(.systemGray6)).cornerRadius(8)
                }
                Text("Практикуй язык в реальных ситуациях с AI-собеседником")
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            .padding(.horizontal)

            // Scenarios
            VStack(spacing: 10) {
                ForEach(scenarios) { scenario in
                    NavigationLink(destination: RoleplayChatView(scenario: scenario)) {
                        RoleplayScenarioCard(scenario: scenario)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RoleplayScenario: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let description: String
    let level: String
    let tag: String
    let tagColor: Color
    let messages: Int
}

struct RoleplayScenarioCard: View {
    let scenario: RoleplayScenario

    var levelColor: Color {
        switch scenario.level {
        case "A2": return .green
        case "B1": return .blue
        case "B2": return .orange
        case "C1": return .red
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(scenario.emoji)
                .font(.title2)
                .frame(width: 52, height: 52)
                .background(scenario.tagColor.opacity(0.1))
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(scenario.title).font(.subheadline).fontWeight(.semibold)
                    Text(scenario.level).font(.caption2).bold().foregroundColor(levelColor)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(levelColor.opacity(0.1)).cornerRadius(4)
                }
                Text(scenario.description).font(.caption).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Text(scenario.tag).font(.caption2).foregroundColor(scenario.tagColor)
                    Text("·").foregroundColor(.secondary)
                    Text("~\(scenario.messages) реплик").font(.caption2).foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Roleplay Chat View
struct RoleplayChatView: View {
    let scenario: RoleplayScenario
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isTyping = false
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Intro
                        VStack(spacing: 6) {
                            Text(scenario.emoji).font(.system(size: 40))
                            Text(scenario.title).font(.headline)
                            Text(scenario.description).font(.caption).foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .padding(.top, 8)

                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .padding(.horizontal)
                                .id(msg.id)
                        }

                        if isTyping {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }.padding(.horizontal)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
                .onChange(of: isTyping) { _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            Divider()

            // Input
            HStack(spacing: 12) {
                TextField("Напиши по-немецки...", text: $inputText)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)

                Button {
                    guard !inputText.isEmpty else { return }
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .secondary : .blue)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(scenario.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startConversation() }
    }

    func startConversation() {
        isTyping = true
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            let greeting = getGreeting()
            isTyping = false
            withAnimation {
                messages.append(ChatMessage(text: greeting, isUser: false))
            }
        }
    }

    func getGreeting() -> String {
        switch scenario.title {
        case "At the Doctor": return "Guten Tag! Ich bin Dr. Müller. Was kann ich für Sie tun? (How can I help you today?)"
        case "Movie Discussion": return "Hey! Hast du den neuen Film gesehen? Was hast du gedacht? (Did you see the new film? What did you think?)"
        case "At the Restaurant": return "Willkommen! Haben Sie eine Reservierung? (Welcome! Do you have a reservation?)"
        case "At the Airport": return "Guten Morgen! Ihren Reisepass und Ihre Bordkarte bitte. (Good morning! Your passport and boarding pass please.)"
        default: return "Hallo! Schön, Sie kennenzulernen. Wie kann ich Ihnen helfen? (Hello! Nice to meet you. How can I help you?)"
        }
    }

    func sendMessage() {
        let text = inputText
        inputText = ""
        messages.append(ChatMessage(text: text, isUser: true))
        isTyping = true
        isLoading = true

        Task {
            let reply = await getRoleplayReply(userMessage: text)
            isTyping = false
            isLoading = false
            withAnimation {
                messages.append(ChatMessage(text: reply, isUser: false))
            }
        }
    }

    func getRoleplayReply(userMessage: String) async -> String {
        struct RoleplayRequest: Codable {
            let scenario: String
            let message: String
            let history: [String]
        }

        struct RoleplayResponse: Codable {
            let reply: String
            let correction: String?
            let tip: String?
        }

        let historyTexts = messages.map { "\($0.isUser ? "User" : "AI"): \($0.text)" }
        let body = RoleplayRequest(scenario: scenario.title, message: userMessage, history: historyTexts)

        if let response: RoleplayResponse = try? await NetworkManager.shared.request("/languages/roleplay", method: "POST", body: body) {
            var result = response.reply
            if let correction = response.correction, !correction.isEmpty {
                result += "\n\n✏️ \(correction)"
            }
            if let tip = response.tip, !tip.isEmpty {
                result += "\n💡 \(tip)"
            }
            return result
        }

        // Fallback
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return "Interessant! Können Sie das genauer erklären? (Interesting! Can you explain that in more detail?)"
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.text)
                .font(.subheadline)
                .padding(12)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(18)
                .cornerRadius(message.isUser ? 4 : 18, corners: message.isUser ? .topRight : .topLeft)

            if !message.isUser { Spacer() }
        }
    }
}

struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animate)
            }
        }
        .padding(12)
        .background(Color(.systemGray5))
        .cornerRadius(18)
        .onAppear { animate = true }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @State private var selected: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss

    init(value: String, onSave: @escaping (String) -> Void) {
        self._selected = State(initialValue: value)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(LanguageConfig.all, id: \.code) { lang in
                    Button {
                        selected = lang.code
                    } label: {
                        HStack(spacing: 14) {
                            Text(lang.flag).font(.title2)
                            Text(lang.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected == lang.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Язык обучения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { onSave(selected); dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
