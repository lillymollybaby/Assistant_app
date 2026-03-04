import SwiftUI

// MARK: - Shopping Category (UI)
enum ShoppingCategory: String, CaseIterable {
    case vegetables = "Овощи и фрукты"
    case meat = "Мясо и рыба"
    case dairy = "Молочные"
    case grains = "Крупы и хлеб"
    case other = "Другое"

    var icon: String {
        switch self {
        case .vegetables: return "leaf.fill"
        case .meat:       return "fish.fill"
        case .dairy:      return "cup.and.saucer.fill"
        case .grains:     return "birthday.cake.fill"
        case .other:      return "bag.fill"
        }
    }

    var color: Color {
        switch self {
        case .vegetables: return .green
        case .meat:       return .red
        case .dairy:      return .blue
        case .grains:     return .brown
        case .other:      return .gray
        }
    }

    var sortOrder: Int {
        switch self {
        case .vegetables: return 0
        case .meat:       return 1
        case .dairy:      return 2
        case .grains:     return 3
        case .other:      return 4
        }
    }

    var apiValue: String {
        switch self {
        case .vegetables: return "vegetables"
        case .meat:       return "meat"
        case .dairy:      return "dairy"
        case .grains:     return "grains"
        case .other:      return "other"
        }
    }

    static func from(api value: String?) -> ShoppingCategory {
        guard let value = value?.lowercased() else { return .other }
        switch value {
        case "vegetables": return .vegetables
        case "meat":       return .meat
        case "dairy":      return .dairy
        case "grains":     return .grains
        default:           return .other
        }
    }
}

// MARK: - ShoppingItemResponse Extensions
extension ShoppingItemResponse {
    var shoppingCategory: ShoppingCategory {
        ShoppingCategory.from(api: category)
    }
}

// MARK: - Shopping List View
struct ShoppingListView: View {
    @Environment(\.dismiss) var dismiss

    @State private var items: [ShoppingItemResponse] = []
    @State private var isLoading = true
    @State private var showAddSheet = false
    @State private var selectedSection = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isTransferring = false
    @State private var transferMessage: String?

    // MARK: - Computed sections
    var needToBuy: [ShoppingItemResponse] {
        items.filter { !$0.is_checked && $0.from_recipe == nil }
            .sorted { ShoppingCategory.from(api: $0.category).sortOrder < ShoppingCategory.from(api: $1.category).sortOrder }
    }

    var fromRecipes: [ShoppingItemResponse] {
        items.filter { !$0.is_checked && $0.from_recipe != nil }
            .sorted { ShoppingCategory.from(api: $0.category).sortOrder < ShoppingCategory.from(api: $1.category).sortOrder }
    }

    var bought: [ShoppingItemResponse] {
        items.filter { $0.is_checked }
    }

    var totalItems: Int { items.filter { !$0.is_checked }.count }
    var checkedItems: Int { items.filter { $0.is_checked }.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        loadingView
                    } else {
                        // MARK: - Progress Header
                        progressHeader

                        // MARK: - Section Picker
                        sectionPicker

                        // MARK: - Content
                        switch selectedSection {
                        case 0:  needToBuySection
                        case 1:  fromRecipesSection
                        case 2:  boughtSection
                        default: EmptyView()
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Список покупок")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            // share
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .symbolRenderingMode(.hierarchical)
                        }
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddShoppingItemSheet(onAdd: { name, amount, category in
                    await addItemAsync(name: name, amount: amount, category: category)
                })
            }
            .task { await loadItemsAsync() }
            .refreshable { await loadItemsAsync() }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
            .overlay {
                if let msg = transferMessage {
                    transferToast(msg)
                }
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Загрузка списка...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Transfer Toast
    private func transferToast(_ msg: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "refrigerator.fill")
                    .foregroundStyle(.white)
                Text(msg)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.blue.gradient)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.bottom, 30)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { transferMessage = nil }
            }
        }
    }

    // MARK: - Progress Header
    private var progressHeader: some View {
        let total = items.count
        let done = checkedItems
        let pct = total > 0 ? Double(done) / Double(total) : 0

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(done) из \(total)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                    Text("продуктов куплено")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: pct)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6), value: pct)
                    Text("\(Int(pct * 100))%")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.green.gradient)
                        .frame(width: max(6, geo.size.width * pct), height: 6)
                        .animation(.spring(response: 0.6), value: pct)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
        .padding(.horizontal)
    }

    // MARK: - Section Picker
    private var sectionPicker: some View {
        HStack(spacing: 6) {
            SectionTab(title: "Купить", count: needToBuy.count, icon: "cart.fill", isSelected: selectedSection == 0) { selectedSection = 0 }
            SectionTab(title: "Из рецептов", count: fromRecipes.count, icon: "book.fill", isSelected: selectedSection == 1) { selectedSection = 1 }
            SectionTab(title: "Куплено", count: checkedItems, icon: "checkmark.circle.fill", isSelected: selectedSection == 2) { selectedSection = 2 }
        }
        .padding(.horizontal)
    }

    // MARK: - Need to Buy Section
    private var needToBuySection: some View {
        VStack(spacing: 12) {
            if needToBuy.isEmpty {
                emptySection(icon: "cart", text: "Список пуст", sub: "Добавьте продукты вручную или из рецептов")
            } else {
                let grouped = Dictionary(grouping: needToBuy, by: { $0.shoppingCategory })
                let sortedKeys = grouped.keys.sorted { $0.sortOrder < $1.sortOrder }

                ForEach(sortedKeys, id: \.self) { cat in
                    shoppingCategorySection(category: cat, items: grouped[cat] ?? [])
                }
            }
        }
    }

    // MARK: - From Recipes Section
    private var fromRecipesSection: some View {
        VStack(spacing: 12) {
            if fromRecipes.isEmpty {
                emptySection(icon: "book.closed", text: "Нет ингредиентов из рецептов", sub: "Добавьте рецепт — недостающие продукты появятся здесь")
            } else {
                let byRecipe = Dictionary(grouping: fromRecipes, by: { $0.from_recipe ?? "" })
                ForEach(Array(byRecipe.keys.sorted()), id: \.self) { recipeName in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(recipeName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                        .padding(.horizontal)

                        VStack(spacing: 6) {
                            ForEach(byRecipe[recipeName] ?? []) { item in
                                ShoppingItemRow(item: item, onToggle: { await toggleItemAsync(item) })
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - Bought Section
    private var boughtSection: some View {
        VStack(spacing: 12) {
            if bought.isEmpty {
                emptySection(icon: "checkmark.circle", text: "Ничего не куплено", sub: "Отмечайте продукты в магазине")
            } else {
                // Transfer to Fridge Button
                Button {
                    Task { await transferToFridgeAsync() }
                } label: {
                    HStack(spacing: 10) {
                        if isTransferring {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "refrigerator.fill")
                                .font(.body)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Всё в холодильник")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("\(bought.count) продуктов → холодильник")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isTransferring)
                .padding(.horizontal)

                // Clear checked button
                Button {
                    Task { await clearCheckedAsync() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Очистить купленные")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(Capsule())
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    ForEach(bought) { item in
                        ShoppingItemRow(item: item, onToggle: { await toggleItemAsync(item) })
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Category Section
    private func shoppingCategorySection(category: ShoppingCategory, items: [ShoppingItemResponse]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 6) {
                ForEach(items) { item in
                    ShoppingItemRow(item: item, onToggle: { await toggleItemAsync(item) })
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty Section
    private func emptySection(icon: String, text: String, sub: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36)).foregroundStyle(.tertiary)
            Text(text).font(.subheadline).foregroundStyle(.secondary)
            Text(sub).font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - API Methods
    private func loadItemsAsync() async {
        do {
            let fetched = try await NetworkManager.shared.getShoppingItems()
            withAnimation { items = fetched; isLoading = false }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    private func toggleItemAsync(_ item: ShoppingItemResponse) async {
        do {
            let result = try await NetworkManager.shared.toggleShoppingItem(id: item.id)
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                // Re-create the item with updated check state
                let old = items[idx]
                let updated = ShoppingItemResponse(
                    id: old.id, name: old.name, amount: old.amount,
                    category: old.category, is_checked: result.is_checked,
                    from_recipe: old.from_recipe, created_at: old.created_at
                )
                withAnimation { items[idx] = updated }
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func addItemAsync(name: String, amount: String, category: ShoppingCategory) async {
        let create = ShoppingItemCreate(
            name: name,
            amount: amount.isEmpty ? nil : amount,
            category: category.apiValue,
            from_recipe: nil
        )
        do {
            let newItem = try await NetworkManager.shared.addShoppingItem(create)
            withAnimation { items.append(newItem) }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteItemAsync(_ item: ShoppingItemResponse) async {
        do {
            try await NetworkManager.shared.deleteShoppingItem(id: item.id)
            withAnimation { items.removeAll { $0.id == item.id } }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func transferToFridgeAsync() async {
        isTransferring = true
        do {
            let result = try await NetworkManager.shared.transferToFridge()
            // Remove checked items from local list
            withAnimation {
                items.removeAll { $0.is_checked }
                transferMessage = "Перенесено \(result.transferred) продуктов в холодильник"
                isTransferring = false
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isTransferring = false
        }
    }

    private func clearCheckedAsync() async {
        do {
            _ = try await NetworkManager.shared.clearCheckedItems()
            withAnimation { items.removeAll { $0.is_checked } }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Section Tab
struct SectionTab: View {
    let title: String
    let count: Int
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.caption2)
                    Text("\(count)").font(.caption).fontWeight(.bold)
                }
                Text(title).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shopping Item Row
struct ShoppingItemRow: View {
    let item: ShoppingItemResponse
    let onToggle: () async -> Void
    @State private var isToggling = false

    var body: some View {
        Button {
            guard !isToggling else { return }
            isToggling = true
            Task {
                await onToggle()
                isToggling = false
            }
        } label: {
            HStack(spacing: 14) {
                // Checkbox
                ZStack {
                    if isToggling {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: item.is_checked ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.is_checked ? .green : Color(.systemGray3))
                            .animation(.spring(response: 0.3), value: item.is_checked)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(item.is_checked, color: .secondary)
                        .foregroundStyle(item.is_checked ? .secondary : .primary)
                    if let recipe = item.from_recipe {
                        HStack(spacing: 4) {
                            Image(systemName: "book.fill").font(.system(size: 8))
                            Text(recipe).font(.caption2)
                        }
                        .foregroundStyle(.blue.opacity(0.7))
                    }
                }

                Spacer()

                if let amount = item.amount, !amount.isEmpty {
                    Text(amount)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            )
            .opacity(item.is_checked ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    do {
                        try await NetworkManager.shared.deleteShoppingItem(id: item.id)
                    } catch { }
                }
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Shopping Item Sheet
struct AddShoppingItemSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var selectedCategory: ShoppingCategory = .other
    @State private var isSaving = false

    var onAdd: (String, String, ShoppingCategory) async -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Название").font(.caption).foregroundStyle(.secondary)
                        TextField("Например: Молоко", text: $name)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Количество").font(.caption).foregroundStyle(.secondary)
                        TextField("Например: 1л", text: $amount)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Отдел").font(.caption).foregroundStyle(.secondary)
                        ForEach(ShoppingCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: cat.icon)
                                        .font(.body)
                                        .foregroundStyle(cat.color)
                                        .frame(width: 32)
                                    Text(cat.rawValue)
                                        .font(.subheadline)
                                    Spacer()
                                    if selectedCategory == cat {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedCategory == cat ? cat.color.opacity(0.08) : Color(.systemGray6))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        guard !name.isEmpty, !isSaving else { return }
                        isSaving = true
                        Task {
                            await onAdd(name, amount, selectedCategory)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            }
                            Text(isSaving ? "Сохранение..." : "Добавить")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(name.isEmpty ? Color(.systemGray4) : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(name.isEmpty || isSaving)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Добавить продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
