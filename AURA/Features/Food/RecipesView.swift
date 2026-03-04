import SwiftUI

// MARK: - Recipe Category (UI display)
enum RecipeCategory: String, CaseIterable {
    case breakfast = "Завтрак"
    case lunch = "Обед"
    case dinner = "Ужин"
    case snack = "Снеки"

    var apiValue: String {
        switch self {
        case .breakfast: return "breakfast"
        case .lunch:     return "lunch"
        case .dinner:    return "dinner"
        case .snack:     return "snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch:     return "sun.max.fill"
        case .dinner:    return "moon.stars.fill"
        case .snack:     return "cup.and.saucer.fill"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch:     return .yellow
        case .dinner:    return .indigo
        case .snack:     return .mint
        }
    }
}

// MARK: - RecipeResponse helpers
extension RecipeResponse {
    var recipeCategory: RecipeCategory {
        switch category?.lowercased() {
        case "breakfast": return .breakfast
        case "lunch":     return .lunch
        case "dinner":    return .dinner
        case "snack":     return .snack
        default:          return .dinner
        }
    }

    var sfImage: String {
        switch recipeCategory {
        case .breakfast: return "frying.pan.fill"
        case .lunch:     return "fork.knife"
        case .dinner:    return "flame.fill"
        case .snack:     return "cup.and.saucer.fill"
        }
    }

    var availableCount: Int {
        ingredients?.filter { $0.in_fridge == true }.count ?? 0
    }

    var missingCount: Int {
        (ingredients?.count ?? 0) - availableCount
    }

    var isFullyAvailable: Bool { missingCount == 0 }
}


// MARK: - Recipes View
struct RecipesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabBar

                TabView(selection: $selectedTab) {
                    FromFridgeTab().tag(0)
                    ExploreTab().tag(1)
                    MyRecipesTab().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Рецепты")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            RecipeTabButton(title: "Из холодильника", icon: "refrigerator.fill", isSelected: selectedTab == 0) { selectedTab = 0 }
            RecipeTabButton(title: "Explore", icon: "safari.fill", isSelected: selectedTab == 1) { selectedTab = 1 }
            RecipeTabButton(title: "Мои", icon: "heart.fill", isSelected: selectedTab == 2) { selectedTab = 2 }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}


// MARK: - Tab Button
struct RecipeTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption2)
                Text(title).font(.caption).fontWeight(.semibold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - From Fridge Tab
struct FromFridgeTab: View {
    @State private var recipes: [RecipeResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var fridgeCount = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 40, height: 40)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI подобрал рецепты")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("На основе продуктов в вашем холодильнике")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                )

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("AI генерирует рецепты...")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(40)
                } else if recipes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "refrigerator")
                            .font(.system(size: 48)).foregroundStyle(.tertiary)
                        Text("Добавьте продукты в холодильник")
                            .font(.headline).foregroundStyle(.secondary)
                        Text("AI предложит рецепты из того что есть")
                            .font(.subheadline).foregroundStyle(.tertiary)
                    }
                    .padding(40)
                } else {
                    ForEach(Array(recipes.enumerated()), id: \.element.name) { _, recipe in
                        FridgeRecipeCard(recipe: recipe)
                    }
                }
            }
            .padding()
        }
        .refreshable { await loadRecipes() }
        .task { await loadRecipes() }
    }

    private func loadRecipes() async {
        do {
            let response = try await NetworkManager.shared.getRecipesFromFridge()
            await MainActor.run {
                recipes = response.recipes
                fridgeCount = response.fridge_items_count ?? 0
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}


// MARK: - Fridge Recipe Card
struct FridgeRecipeCard: View {
    let recipe: RecipeResponse
    @State private var isCooking = false
    @State private var isSaving = false
    @State private var cookResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: recipe.sfImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(recipe.recipeCategory.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name).font(.headline)
                    HStack(spacing: 12) {
                        Label("\(recipe.calories ?? 0) ккал", systemImage: "flame.fill")
                            .font(.caption).foregroundStyle(.orange)
                        Label("\(recipe.cook_time ?? 0) мин", systemImage: "clock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()

                if recipe.isFullyAvailable {
                    Text("Всё есть ✅")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                } else if recipe.missingCount > 0 {
                    Text("Не хватает \(recipe.missingCount)")
                        .font(.caption2).fontWeight(.bold)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }

            // Ingredients
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(Array(ingredients.enumerated()), id: \.element.name) { _, ing in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ing.in_fridge == true ? Color.green : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                            Text(ing.name)
                                .font(.caption2)
                                .foregroundStyle(ing.in_fridge == true ? .primary : .secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(ing.in_fridge == true ? Color.green.opacity(0.08) : Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                }
            }

            // Cook Result
            if let result = cookResult {
                Text(result)
                    .font(.caption).foregroundStyle(.green)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Actions
            HStack(spacing: 10) {
                Button {
                    saveRecipe()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isSaving ? "checkmark.circle.fill" : "heart")
                        Text(isSaving ? "Сохранено" : "Сохранить")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSaving ? Color.pink.opacity(0.12) : Color(.systemGray6))
                    .foregroundStyle(isSaving ? .pink : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    cookRecipeAction()
                } label: {
                    HStack(spacing: 4) {
                        if isCooking {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "frying.pan.fill")
                        }
                        Text("Приготовить").fontWeight(.semibold)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(recipe.isFullyAvailable ? Color.green : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        )
    }

    private func saveRecipe() {
        Task {
            do {
                let create = RecipeCreate(
                    name: recipe.name,
                    description: recipe.description,
                    ingredients: recipe.ingredients?.map { ing in
                        [
                            "name": AnyEncodable(ing.name),
                            "amount": AnyEncodable(ing.amount ?? ""),
                            "in_fridge": AnyEncodable(ing.in_fridge ?? false)
                        ]
                    },
                    calories: recipe.calories ?? 0,
                    proteins: recipe.proteins ?? 0,
                    fats: recipe.fats ?? 0,
                    carbs: recipe.carbs ?? 0,
                    cook_time: recipe.cook_time ?? 0,
                    category: recipe.category,
                    cuisine: recipe.cuisine,
                    image_url: nil,
                    source: "ai"
                )
                _ = try await NetworkManager.shared.saveRecipe(create)
                await MainActor.run { isSaving = true }
            } catch {
                print("Save error: \(error)")
            }
        }
    }

    private func cookRecipeAction() {
        guard let id = recipe.id else { return }
        isCooking = true
        Task {
            do {
                let result = try await NetworkManager.shared.cookRecipe(id: id)
                await MainActor.run {
                    isCooking = false
                    cookResult = result.message
                }
            } catch {
                await MainActor.run { isCooking = false }
            }
        }
    }
}


// MARK: - Explore Tab
struct ExploreTab: View {
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var searchText = ""
    @State private var recipes: [RecipeResponse] = []
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Search
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Поиск рецептов...", text: $searchText)
                        .font(.subheadline)
                        .onSubmit { loadRecipes() }
                }
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(RecipeCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedCategory = selectedCategory == cat ? nil : cat
                                loadRecipes()
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                        .font(.title3)
                                        .foregroundStyle(selectedCategory == cat ? .white : cat.color)
                                        .frame(width: 48, height: 48)
                                        .background(selectedCategory == cat ? cat.color : cat.color.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(cat.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(selectedCategory == cat ? cat.color : .secondary)
                                        .fontWeight(selectedCategory == cat ? .bold : .regular)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("AI ищет рецепты...")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(40)
                } else if recipes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40)).foregroundStyle(.tertiary)
                        Text("Выберите категорию или\nвведите запрос для поиска")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                } else {
                    ForEach(Array(recipes.enumerated()), id: \.element.name) { _, recipe in
                        ExploreRecipeCard(recipe: recipe)
                    }
                }
            }
            .padding()
        }
        .task { loadRecipes() }
    }

    private func loadRecipes() {
        isLoading = true
        Task {
            do {
                let response = try await NetworkManager.shared.exploreRecipes(
                    category: selectedCategory?.apiValue,
                    query: searchText.isEmpty ? nil : searchText
                )
                await MainActor.run {
                    recipes = response.recipes
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}


// MARK: - Explore Recipe Card
struct ExploreRecipeCard: View {
    let recipe: RecipeResponse
    @State private var addedToShopping = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: recipe.sfImage)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(recipe.recipeCategory.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name).font(.subheadline).fontWeight(.semibold)
                    HStack(spacing: 10) {
                        Label("\(recipe.calories ?? 0) ккал", systemImage: "flame.fill")
                            .font(.caption2).foregroundStyle(.orange)
                        Label("\(recipe.cook_time ?? 0) мин", systemImage: "clock.fill")
                            .font(.caption2).foregroundStyle(.secondary)
                        if let cuisine = recipe.cuisine {
                            Text(cuisine)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
            }

            // Ingredients
            if let ingredients = recipe.ingredients, !ingredients.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(ingredients.enumerated()), id: \.element.name) { _, ing in
                        HStack(spacing: 10) {
                            Image(systemName: ing.in_fridge == true ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(ing.in_fridge == true ? .green : .gray.opacity(0.4))
                            Text(ing.name)
                                .font(.caption)
                                .foregroundStyle(ing.in_fridge == true ? .primary : .secondary)
                            Spacer()
                            Text(ing.amount ?? "")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Add missing to shopping
            if recipe.missingCount > 0 {
                Button {
                    addMissingToShopping()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: addedToShopping ? "checkmark.circle.fill" : "cart.fill.badge.plus")
                        Text(addedToShopping ? "Добавлено в список!" : "Добавить \(recipe.missingCount) в список покупок")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(addedToShopping ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundStyle(addedToShopping ? .green : .blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(addedToShopping)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }

    private func addMissingToShopping() {
        guard let id = recipe.id else { return }
        Task {
            do {
                _ = try await NetworkManager.shared.addMissingToShopping(recipeId: id)
                await MainActor.run { addedToShopping = true }
            } catch {
                print("Add to shopping error: \(error)")
            }
        }
    }
}


// MARK: - My Recipes Tab
struct MyRecipesTab: View {
    @State private var saved: [RecipeResponse] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Загрузка...").padding(40)
                } else if saved.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 48)).foregroundStyle(.tertiary)
                        Text("Нет сохранённых рецептов")
                            .font(.headline).foregroundStyle(.secondary)
                        Text("Сохраняйте рецепты из Explore\nили из холодильника")
                            .font(.subheadline).foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(60)
                } else {
                    ForEach(saved) { recipe in
                        SavedRecipeCard(recipe: recipe) {
                            unsaveRecipe(recipe)
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable { await loadSaved() }
        .task { await loadSaved() }
    }

    private func loadSaved() async {
        do {
            let fetched = try await NetworkManager.shared.getSavedRecipes()
            await MainActor.run {
                saved = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func unsaveRecipe(_ recipe: RecipeResponse) {
        guard let id = recipe.id else { return }
        Task {
            do {
                try await NetworkManager.shared.unsaveRecipe(id: id)
                await MainActor.run {
                    saved.removeAll { $0.id == id }
                }
            } catch {
                print("Unsave error: \(error)")
            }
        }
    }
}


// MARK: - Saved Recipe Card
struct SavedRecipeCard: View {
    let recipe: RecipeResponse
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: recipe.sfImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(recipe.recipeCategory.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name).font(.subheadline).fontWeight(.medium)
                HStack(spacing: 8) {
                    Label("\(recipe.calories ?? 0) ккал", systemImage: "flame.fill")
                        .font(.caption2).foregroundStyle(.orange)
                    Label("\(recipe.cook_time ?? 0) мин", systemImage: "clock.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { onDelete() } label: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }
}


// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }
        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}
