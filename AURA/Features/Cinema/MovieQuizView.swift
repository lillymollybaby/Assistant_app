import SwiftUI

struct MovieQuizView: View {
    let movie: MovieResponse
    @State private var words: [MovieWord] = []
    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var score = 0
    @State private var finished = false
    @State private var isLoading = true
    @State private var userChoice: String? = nil
    @State private var options: [String] = []

    let allTranslations = [
        "преследуемый/проклятый", "зловещий", "предательство", "искупление",
        "одержимость", "месть", "заговор", "обман", "стойкость", "амбиции",
        "коррупция", "изоляция", "манипуляция", "жертва", "загадочный",
        "безжалостный", "отчаянный", "хитрый", "неумолимый", "неизбежный"
    ]

    var currentWord: MovieWord? { words.isEmpty ? nil : words[currentIndex] }
    var progress: Double { words.isEmpty ? 0 : Double(currentIndex) / Double(words.count) }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Загружаем слова...").font(.subheadline).foregroundColor(.secondary)
                }
            } else if finished {
                QuizResultView(score: score, total: words.count, movie: movie)
            } else if let word = currentWord {
                VStack(spacing: 0) {
                    // Progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("Вопрос \(currentIndex + 1) из \(words.count)")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Text("⭐ \(score)").font(.subheadline).bold()
                        }
                        ProgressView(value: progress)
                            .tint(.orange)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    }
                    .padding()
                    .background(Color(.systemBackground))

                    ScrollView {
                        VStack(spacing: 24) {
                            // Word card
                            VStack(spacing: 12) {
                                Text(word.word)
                                    .font(.system(size: 36, weight: .bold))
                                    .multilineTextAlignment(.center)

                                if let example = word.example {
                                    Text("💬 \(example)")
                                        .font(.subheadline).italic()
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }

                                if let context = word.context, showAnswer {
                                    Text("📍 \(context)")
                                        .font(.caption).foregroundColor(.blue)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                        .transition(.opacity)
                                }
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemBackground))
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                            .padding(.horizontal)

                            Text("Что означает это слово?")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            VStack(spacing: 10) {
                                ForEach(options, id: \.self) { option in
                                    QuizOptionButton(
                                        text: option,
                                        state: optionState(option),
                                        isDisabled: showAnswer
                                    ) {
                                        guard !showAnswer else { return }
                                        userChoice = option
                                        withAnimation { showAnswer = true }
                                        if option == word.translation { score += 1 }
                                    }
                                }
                            }
                            .padding(.horizontal)

                            if showAnswer {
                                Button {
                                    withAnimation {
                                        if currentIndex + 1 >= words.count {
                                            finished = true
                                        } else {
                                            currentIndex += 1
                                            showAnswer = false
                                            userChoice = nil
                                            generateOptions()
                                        }
                                    }
                                } label: {
                                    Text(currentIndex + 1 >= words.count ? "Завершить" : "Следующий →")
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(16)
                                }
                                .padding(.horizontal)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
        }
        .navigationTitle("Квиз: \(movie.title)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadWords() }
    }

    func optionState(_ option: String) -> QuizOptionState {
        guard showAnswer else { return .normal }
        if option == currentWord?.translation { return .correct }
        if option == userChoice { return .wrong }
        return .normal
    }

    func loadWords() {
        Task {
            let result = try? await NetworkManager.shared.getMovieWords(tmdbId: movie.stableId)
            words = result?.words ?? []
            isLoading = false
            generateOptions()
        }
    }

    func generateOptions() {
        guard let word = currentWord else { return }
        var opts = [word.translation]
        let distractors = allTranslations.filter { $0 != word.translation }.shuffled().prefix(3)
        opts.append(contentsOf: distractors)
        options = opts.shuffled()
    }
}

enum QuizOptionState { case normal, correct, wrong }

struct QuizOptionButton: View {
    let text: String
    let state: QuizOptionState
    let isDisabled: Bool
    let action: () -> Void

    var bgColor: Color {
        switch state {
        case .normal: return Color(.systemBackground)
        case .correct: return Color.green.opacity(0.15)
        case .wrong: return Color.red.opacity(0.15)
        }
    }

    var borderColor: Color {
        switch state {
        case .normal: return Color.clear
        case .correct: return Color.green
        case .wrong: return Color.red
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text).font(.subheadline).fontWeight(.medium)
                Spacer()
                if state == .correct { Image(systemName: "checkmark.circle.fill").foregroundColor(.green) }
                else if state == .wrong { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }
            }
            .padding()
            .background(bgColor)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1.5))
        }
        .foregroundColor(.primary)
        .disabled(isDisabled)
        .animation(.spring(response: 0.3), value: state)
    }
}

struct QuizResultView: View {
    let score: Int
    let total: Int
    let movie: MovieResponse
    @Environment(\.dismiss) var dismiss

    var percentage: Double { total > 0 ? Double(score) / Double(total) : 0 }
    var emoji: String {
        if percentage >= 0.8 { return "🏆" }
        if percentage >= 0.6 { return "👍" }
        return "📚"
    }
    var message: String {
        if percentage >= 0.8 { return "Отлично! Ты хорошо знаешь этот фильм" }
        if percentage >= 0.6 { return "Неплохо! Продолжай изучать" }
        return "Есть куда расти! Пересмотри слова"
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(emoji).font(.system(size: 70))
            VStack(spacing: 8) {
                Text("\(score)/\(total)").font(.system(size: 52, weight: .bold))
                Text(message).font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 12).frame(width: 100, height: 100)
                Circle().trim(from: 0, to: percentage)
                    .stroke(percentage >= 0.6 ? Color.green : Color.orange,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(percentage * 100))%").font(.headline).bold()
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Готово")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
