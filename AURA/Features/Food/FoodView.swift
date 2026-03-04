import SwiftUI
import PhotosUI

struct FoodView: View {
    @State private var summary: DailySummaryResponse?
    @State private var meals: [MealResponse] = []
    @State private var showAddSheet = false
    @State private var showScanSheet = false
    @State private var error: AppError?
    @State private var dinnerIdeas: String?
    @State private var isLoadingIdeas = false
    @State private var isLoading = true
    @State private var showManualAdd = false
    @State private var showFridge = false
    @State private var showRecipes = false
    @State private var showShoppingList = false

    var effectiveCalorieGoal: Int {
        summary?.calorie_goal ?? ProfileSettings.shared.calorieGoal
    }

    var progress: Double {
        guard let s = summary, effectiveCalorieGoal > 0 else { return 0 }
        return min(s.total_calories / Double(effectiveCalorieGoal), 1.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Калории — главная карточка
                    calorieCard
                    
                    // MARK: - Макронутриенты
                    macrosCard

                    // MARK: - Быстрые действия
                    quickActionsRow

                    // MARK: - AI Совет
                    if let advice = summary?.ai_advice, !advice.isEmpty {
                        aiAdviceCard(advice)
                    }

                    // MARK: - Приёмы пищи
                    if !meals.isEmpty {
                        mealsSection
                    }

                    // MARK: - Идеи для ужина
                    dinnerIdeasCard

                    // MARK: - Health Sync
                    HealthSyncCard()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Food")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showAddSheet = true } label: {
                            Label("Фото еды", systemImage: "camera")
                        }
                        Button { showManualAdd = true } label: {
                            Label("Вручную", systemImage: "square.and.pencil")
                        }
                        Button { showScanSheet = true } label: {
                            Label("Сканировать", systemImage: "barcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .errorAlert($error)
            .sheet(isPresented: $showAddSheet, onDismiss: {
                Task { await refreshData() }
            }) {
                PhotoFoodSheet()
            }
            .sheet(isPresented: $showScanSheet) {
                ScanDecideView()
            }
            .sheet(isPresented: $showManualAdd, onDismiss: {
                Task { await refreshData() }
            }) {
                NavigationStack {
                    ManualAddFoodView(onAdd: { _ in Task { await refreshData() } })
                }
            }
            .fullScreenCover(isPresented: $showFridge) {
                FridgeView()
            }
            .fullScreenCover(isPresented: $showRecipes) {
                RecipesView()
            }
            .fullScreenCover(isPresented: $showShoppingList) {
                ShoppingListView()
            }
            .task { await refreshData() }
            .refreshable { await refreshData() }
        }
    }

    // MARK: - Calorie Card
    private var calorieCard: some View {
        let calGoal = effectiveCalorieGoal
        let calEaten = Int(summary?.total_calories ?? 0)
        let calLeft = max(0, calGoal - calEaten)

        return VStack(spacing: 16) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 14)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.green, .mint, .cyan, .blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: progress)

                VStack(spacing: 2) {
                    Text("\(calLeft)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("осталось")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats row
            HStack(spacing: 0) {
                CalorieStat(value: "\(calGoal)", label: "Цель", icon: "target", color: .blue)
                CalorieStat(value: "\(calEaten)", label: "Съедено", icon: "flame.fill", color: .orange)
                CalorieStat(value: "\(calLeft)", label: "Осталось", icon: "leaf.fill", color: .green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Macros Card
    private var macrosCard: some View {
        HStack(spacing: 12) {
            MacroPill(label: "Белки", value: summary?.total_proteins ?? 0, goal: Double(summary?.protein_goal ?? 150), color: .blue, icon: "fish.fill")
            MacroPill(label: "Углеводы", value: summary?.total_carbs ?? 0, goal: Double(summary?.carbs_goal ?? 250), color: .orange, icon: "leaf.fill")
            MacroPill(label: "Жиры", value: summary?.total_fats ?? 0, goal: Double(summary?.fat_goal ?? 70), color: .purple, icon: "drop.fill")
        }
        .padding(.horizontal)
    }

    // MARK: - Quick Actions
    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Холодильник", icon: "refrigerator.fill", color: .cyan) {
                showFridge = true
            }
            QuickActionButton(title: "Рецепты", icon: "book.fill", color: .orange) {
                showRecipes = true
            }
            QuickActionButton(title: "Покупки", icon: "cart.fill", color: .purple) {
                showShoppingList = true
            }
        }
        .padding(.horizontal)
    }

    // MARK: - AI Advice
    private func aiAdviceCard(_ advice: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.yellow)
                .frame(width: 36, height: 36)
                .background(Color.yellow.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Совет AI")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(advice)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    // MARK: - Meals Section
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Сегодня")
                    .font(.headline)
                Spacer()
                Text("\(meals.count) приёмов")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(meals) { meal in
                    MealCard(meal: meal, onDelete: {
                        Task {
                            try? await NetworkManager.shared.deleteMeal(id: meal.id)
                            await refreshData()
                        }
                    })
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Dinner Ideas
    private var dinnerIdeasCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let ideas = dinnerIdeas {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                        .frame(width: 36, height: 36)
                        .background(Color.indigo.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Идеи для ужина")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        Text(ideas).font(.subheadline)
                    }
                    Spacer()
                }
            } else {
                Button {
                    isLoadingIdeas = true
                    Task {
                        if let r = try? await NetworkManager.shared.getDinnerIdeas() {
                            dinnerIdeas = r.ideas
                        }
                        isLoadingIdeas = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isLoadingIdeas {
                            ProgressView()
                        } else {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.indigo)
                        }
                        Text(isLoadingIdeas ? "Генерируем..." : "Идеи для ужина от AI")
                            .font(.subheadline).fontWeight(.medium)
                        Spacer()
                        if !isLoadingIdeas {
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                .disabled(isLoadingIdeas)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .padding(.horizontal)
    }

    func refreshData() async {
        do {
            async let s = NetworkManager.shared.getTodaySummary()
            async let m = NetworkManager.shared.getMealHistory()
            summary = try await s
            meals = try await m
            isLoading = false
        } catch {
            isLoading = false
            self.error = AppError(error)
        }
    }
}

// MARK: - Calorie Stat
struct CalorieStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Macro Pill
struct MacroPill: View {
    let label: String
    let value: Double
    let goal: Double
    let color: Color
    let icon: String

    var pct: Double { goal > 0 ? min(value / goal, 1.0) : 0 }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.15))
                    .frame(height: 6)
                Capsule()
                    .fill(color)
                    .frame(width: max(6, CGFloat(pct) * 100), height: 6)
                    .animation(.spring(response: 0.8), value: pct)
            }

            Text("\(Int(value))/\(Int(goal))г")
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meal Card
struct MealCard: View {
    let meal: MealResponse
    let onDelete: () -> Void

    var mealIcon: String {
        switch meal.meal_type {
        case "breakfast": return "sunrise.fill"
        case "lunch":     return "sun.max.fill"
        case "dinner":    return "moon.stars.fill"
        default:          return "fork.knife"
        }
    }

    var mealColor: Color {
        switch meal.meal_type {
        case "breakfast": return .orange
        case "lunch":     return .yellow
        case "dinner":    return .indigo
        default:          return .gray
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mealIcon)
                .font(.body)
                .foregroundStyle(mealColor)
                .frame(width: 40, height: 40)
                .background(mealColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if let tip = meal.ai_analysis, !tip.isEmpty {
                    Text(tip)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.calories))")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                Text("ккал")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

struct PhotoFoodSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var analyzedMeal: MealResponse? = nil
    @State private var isAnalyzing = false
    @State private var errorMessage = ""
    @State private var mealType = "snack"
    @State private var savedSuccessfully = false

    let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    let mealLabels = ["Завтрак", "Обед", "Ужин", "Перекус"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Meal type picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Тип приёма пищи").font(.subheadline).foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            ForEach(0..<4) { i in
                                Button {
                                    mealType = mealTypes[i]
                                } label: {
                                    Text(mealLabels[i])
                                        .font(.caption).fontWeight(.semibold)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(mealType == mealTypes[i] ? Color.blue : Color(.systemGray6))
                                        .foregroundColor(mealType == mealTypes[i] ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Photo picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(height: 220)

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue.opacity(0.7))
                                    Text("Нажми чтобы выбрать фото")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Gemini AI определит КБЖУ")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: selectedItem) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                                await analyzePhoto(imageData: data)
                            }
                        }
                    }

                    // Loading
                    if isAnalyzing {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Gemini анализирует фото...")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding()
                    }

                    // Result
                    if let meal = analyzedMeal {
                        AnalyzedMealCard(meal: meal)
                            .padding(.horizontal)

                        if savedSuccessfully {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("Добавлено в дневник!").fontWeight(.semibold).foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }

                    // Error
                    if !errorMessage.isEmpty {
                        Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
                    }
                }
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Добавить еду")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                if savedSuccessfully {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") { dismiss() }
                            .fontWeight(.bold)
                    }
                }
            }
        }
    }

    func analyzePhoto(imageData: Data) async {
        isAnalyzing = true
        errorMessage = ""
        do {
            let meal = try await NetworkManager.shared.analyzeFoodPhoto(imageData: imageData, mealType: mealType)
            analyzedMeal = meal
            savedSuccessfully = true
        } catch {
            errorMessage = "Ошибка анализа: \(error.localizedDescription)"
        }
        isAnalyzing = false
    }
}

struct AnalyzedMealCard: View {
    let meal: MealResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name).font(.title3).bold()
                    if let tip = meal.ai_analysis, !tip.isEmpty {
                        Text(tip).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(meal.calories))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.orange)
                    Text("ккал").font(.caption).foregroundColor(.secondary)
                }
            }

            Divider()

            HStack(spacing: 0) {
                MacroStat(value: Int(meal.proteins), label: "Белки", unit: "г", color: .blue)
                Divider().frame(height: 40)
                MacroStat(value: Int(meal.carbs), label: "Углеводы", unit: "г", color: .orange)
                Divider().frame(height: 40)
                MacroStat(value: Int(meal.fats), label: "Жиры", unit: "г", color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.green.opacity(0.2), lineWidth: 1.5)
        )
    }
}

struct MacroStat: View {
    let value: Int
    let label: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)\(unit)").font(.title3).bold().foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Manual Add Food View
struct ManualAddFoodView: View {
    let onAdd: (MealResponse) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var calories = ""
    @State private var proteins = ""
    @State private var carbs = ""
    @State private var fats = ""
    @State private var mealType = "snack"
    @State private var isLoading = false
    @State private var errorMessage = ""

    let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    let mealLabels = ["🌅 Завтрак", "☀️ Обед", "🌙 Ужин", "🍽️ Перекус"]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Meal type
                VStack(alignment: .leading, spacing: 10) {
                    Text("Тип").font(.subheadline).bold().padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<4) { i in
                                Button {
                                    mealType = mealTypes[i]
                                } label: {
                                    Text(mealLabels[i])
                                        .font(.subheadline).fontWeight(.semibold)
                                        .padding(.horizontal, 16).padding(.vertical, 10)
                                        .background(mealType == mealTypes[i] ? Color.blue : Color(.systemBackground))
                                        .foregroundColor(mealType == mealTypes[i] ? .white : .primary)
                                        .cornerRadius(20)
                                        .shadow(color: .black.opacity(0.05), radius: 4)
                                }
                            }
                        }.padding(.horizontal)
                    }
                }

                // Fields
                VStack(spacing: 12) {
                    ManualField(title: "Название блюда", placeholder: "Например: Греческий салат", text: $name, keyboard: .default)
                    ManualField(title: "Калории (ккал)", placeholder: "0", text: $calories, keyboard: .numberPad)

                    HStack(spacing: 12) {
                        ManualField(title: "Белки (г)", placeholder: "0", text: $proteins, keyboard: .numberPad)
                        ManualField(title: "Углеводы (г)", placeholder: "0", text: $carbs, keyboard: .numberPad)
                        ManualField(title: "Жиры (г)", placeholder: "0", text: $fats, keyboard: .numberPad)
                    }
                }
                .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
                }

                // Add button
                Button {
                    Task { await addMeal() }
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.white) }
                        else { Image(systemName: "plus.circle.fill"); Text("Добавить").fontWeight(.bold) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(name.isEmpty ? Color(.systemGray4) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(name.isEmpty || isLoading)
                .padding(.horizontal)
            }
            .padding(.top, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Добавить вручную")
        .navigationBarTitleDisplayMode(.inline)
    }

    func addMeal() async {
        guard !name.isEmpty else { return }
        isLoading = true
        errorMessage = ""

        struct ManualMeal: Codable {
            let name: String
            let calories: Double
            let proteins: Double
            let fats: Double
            let carbs: Double
            let meal_type: String
        }

        let body = ManualMeal(
            name: name,
            calories: Double(calories) ?? 0,
            proteins: Double(proteins) ?? 0,
            fats: Double(fats) ?? 0,
            carbs: Double(carbs) ?? 0,
            meal_type: mealType
        )

        if let meal: MealResponse = try? await NetworkManager.shared.request("/food/manual", method: "POST", body: body) {
            onAdd(meal)
            dismiss()
        } else {
            errorMessage = "Не удалось добавить блюдо"
        }

        isLoading = false
    }
}

struct ManualField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}

struct HealthSyncCard: View {
    @ObservedObject var health = HealthKitManager.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.text.square.fill").foregroundColor(.red)
                Text("Health Sync").font(.headline)
                Spacer()
                if !health.isAuthorized {
                    Button("Подключить") { health.requestAuthorization() }
                        .font(.caption).foregroundColor(.blue)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1)).cornerRadius(20)
                } else {
                    Text("Apple Health ✓").font(.caption2).foregroundColor(.green)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                HealthTile(icon: "figure.walk", iconColor: .red, value: health.steps > 0 ? health.stepsFormatted : "—", label: "Шагов", note: health.stepsGoalNote)
                HealthTile(icon: "flame.fill", iconColor: .orange, value: "\(Int(health.activeCalories))", label: "Акт. ккал", note: health.calorieAdjustment > 0 ? "+\(health.calorieAdjustment) к норме" : "В норме")
                HealthTile(icon: "bed.double.fill", iconColor: .indigo, value: health.sleepHours > 0 ? health.sleepFormatted : "—", label: "Сон", note: health.sleepHours >= 7 ? "Хороший отдых" : "Нет данных")
                HealthTile(icon: "heart.fill", iconColor: .pink, value: health.heartRateFormatted, label: "Пульс", note: "уд/мин")
            }
            if health.isAuthorized {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").foregroundColor(.orange)
                    Text(health.healthAdvice).font(.caption).foregroundColor(.secondary)
                }
                .padding(10).background(Color.orange.opacity(0.08)).cornerRadius(10)
            }
        }
        .padding().background(Color(.systemBackground)).cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .onAppear { if health.isAuthorized { health.fetchAll() } }
    }
}

struct HealthTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    let note: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).foregroundColor(iconColor).font(.subheadline)
            Text(value).font(.title3).fontWeight(.bold)
            Text(label).font(.caption).foregroundColor(.secondary)
            if !note.isEmpty { Text(note).font(.caption2).foregroundColor(.secondary.opacity(0.7)) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(iconColor.opacity(0.06))
        .cornerRadius(14)
    }
}
