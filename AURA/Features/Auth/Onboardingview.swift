import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var name = ""
    @State private var calorieGoal = "2200"
    @State private var selectedLanguage = "German"
    @State private var isFinishing = false
    let onComplete: () -> Void

    let pages: [OnboardingPage] = [
        OnboardingPage(
            emoji: "✨",
            title: "Добро пожаловать\nв AURA",
            subtitle: "AI-ассистент который делает твою жизнь умнее — в кино, языках, еде и маршрутах",
            gradient: [Color(red:0.3,green:0.1,blue:0.8), Color(red:0.1,green:0.3,blue:1.0)]
        ),
        OnboardingPage(
            emoji: "🎬",
            title: "Cinema",
            subtitle: "Учи язык через фильмы. Редкие слова, квизы по диалогам, AI рецензии",
            gradient: [Color(red:0.5,green:0.1,blue:0.8), Color(red:0.8,green:0.2,blue:0.5)]
        ),
        OnboardingPage(
            emoji: "🥗",
            title: "Food",
            subtitle: "Сфотографируй тарелку — AI посчитает КБЖУ. Умные советы по питанию",
            gradient: [Color(red:0.1,green:0.6,blue:0.3), Color(red:0.0,green:0.8,blue:0.5)]
        ),
        OnboardingPage(
            emoji: "📍",
            title: "Logistics",
            subtitle: "Умные маршруты с учётом пробок. Никогда не опаздывай снова",
            gradient: [Color(red:0.9,green:0.4,blue:0.1), Color(red:1.0,green:0.6,blue:0.0)]
        ),
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: currentPage < pages.count ? pages[currentPage].gradient : [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            // Stars/particles effect
            GeometryReader { geo in
                ForEach(0..<12, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.05...0.15)))
                        .frame(width: CGFloat.random(in: 4...12))
                        .position(
                            x: CGFloat(i * 73 % Int(geo.size.width)),
                            y: CGFloat(i * 97 % Int(geo.size.height))
                        )
                }
            }
            .ignoresSafeArea()

            if currentPage < pages.count {
                // Feature pages
                VStack(spacing: 0) {
                    Spacer()

                    // Emoji
                    Text(pages[currentPage].emoji)
                        .font(.system(size: 80))
                        .padding(.bottom, 32)
                        .id(currentPage)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.5), value: currentPage)

                    // Title
                    Text(pages[currentPage].title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .id("title-\(currentPage)")
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .animation(.spring(response: 0.5), value: currentPage)

                    Text(pages[currentPage].subtitle)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        .id("sub-\(currentPage)")
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)

                    Spacer()

                    // Dots
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count + 1, id: \.self) { i in
                            Circle()
                                .fill(Color.white.opacity(i == currentPage ? 1.0 : 0.3))
                                .frame(width: i == currentPage ? 20 : 8, height: 8)
                                .animation(.spring(response: 0.3), value: currentPage)
                        }
                    }
                    .padding(.bottom, 32)

                    // Next button
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            currentPage += 1
                        }
                    } label: {
                        Text(currentPage == pages.count - 1 ? "Настроить профиль →" : "Далее →")
                            .font(.headline)
                            .foregroundColor(pages[currentPage].gradient[0])
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            } else {
                // Setup page
                SetupProfilePage(
                    name: $name,
                    calorieGoal: $calorieGoal,
                    selectedLanguage: $selectedLanguage,
                    isLoading: isFinishing
                ) {
                    isFinishing = true
                    UserDefaults.standard.set(true, forKey: "onboarding_completed")
                    UserDefaults.standard.set(name, forKey: "user_display_name")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }
        }
    }
}

struct OnboardingPage {
    let emoji: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

struct SetupProfilePage: View {
    @Binding var name: String
    @Binding var calorieGoal: String
    @Binding var selectedLanguage: String
    let isLoading: Bool
    let onComplete: () -> Void

    let languages = ["English", "German", "French", "Spanish", "Japanese", "Chinese"]
    let goals = ["1500", "1800", "2000", "2200", "2500", "3000"]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("👤").font(.system(size: 60))
                    Text("Расскажи о себе")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Персонализируем AURA под тебя")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 60)

                VStack(spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Твоё имя").font(.caption).foregroundColor(.white.opacity(0.8))
                        TextField("Например: Алексей", text: $name)
                            .padding(14)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }

                    // Language
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Изучаю язык").font(.caption).foregroundColor(.white.opacity(0.8))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(languages, id: \.self) { lang in
                                    Button {
                                        selectedLanguage = lang
                                    } label: {
                                        Text(langEmoji(lang) + " " + lang)
                                            .font(.subheadline).fontWeight(.semibold)
                                            .padding(.horizontal, 14).padding(.vertical, 10)
                                            .background(selectedLanguage == lang ? Color.white : Color.white.opacity(0.15))
                                            .foregroundColor(selectedLanguage == lang ? Color(red:0.3,green:0.1,blue:0.8) : .white)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }

                    // Calorie goal
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Цель калорий в день").font(.caption).foregroundColor(.white.opacity(0.8))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(goals, id: \.self) { goal in
                                    Button {
                                        calorieGoal = goal
                                    } label: {
                                        Text(goal + " ккал")
                                            .font(.subheadline).fontWeight(.semibold)
                                            .padding(.horizontal, 14).padding(.vertical, 10)
                                            .background(calorieGoal == goal ? Color.white : Color.white.opacity(0.15))
                                            .foregroundColor(calorieGoal == goal ? Color(red:0.1,green:0.6,blue:0.3) : .white)
                                            .cornerRadius(20)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer(minLength: 40)

                Button {
                    onComplete()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(Color(red:0.3,green:0.1,blue:0.8))
                        } else {
                            Text("Начать пользоваться AURA")
                                .font(.headline)
                                .foregroundColor(Color(red:0.3,green:0.1,blue:0.8))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .disabled(isLoading)
            }
        }
    }

    func langEmoji(_ lang: String) -> String {
        switch lang {
        case "English": return "🇬🇧"
        case "German": return "🇩🇪"
        case "French": return "🇫🇷"
        case "Spanish": return "🇪🇸"
        case "Japanese": return "🇯🇵"
        case "Chinese": return "🇨🇳"
        default: return "🌍"
        }
    }
}
