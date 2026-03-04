import SwiftUI

// MARK: - UI Enums
enum Freshness {
    case fresh, warning, critical, expired

    var color: Color {
        switch self {
        case .fresh:    return .green
        case .warning:  return .orange
        case .critical: return .red
        case .expired:  return .gray
        }
    }

    var label: String {
        switch self {
        case .fresh:    return "Свежий"
        case .warning:  return "Скоро"
        case .critical: return "Срочно"
        case .expired:  return "Просрочен"
        }
    }

    var icon: String {
        switch self {
        case .fresh:    return "checkmark.circle.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "flame.fill"
        case .expired:  return "xmark.circle.fill"
        }
    }
}

enum FridgeCategory: String, CaseIterable {
    case meat = "Мясо"
    case dairy = "Молочные"
    case vegetables = "Овощи"
    case fruits = "Фрукты"
    case grains = "Крупы"
    case other = "Другое"

    var apiValue: String {
        switch self {
        case .meat:       return "meat"
        case .dairy:      return "dairy"
        case .vegetables: return "vegetables"
        case .fruits:     return "fruits"
        case .grains:     return "grains"
        case .other:      return "other"
        }
    }

    static func from(api: String) -> FridgeCategory {
        switch api {
        case "meat":       return .meat
        case "dairy":      return .dairy
        case "vegetables": return .vegetables
        case "fruits":     return .fruits
        case "grains":     return .grains
        default:           return .other
        }
    }

    var icon: String {
        switch self {
        case .meat:       return "🥩"
        case .dairy:      return "🥛"
        case .vegetables: return "🥬"
        case .fruits:     return "🍎"
        case .grains:     return "🌾"
        case .other:      return "📦"
        }
    }

    var color: Color {
        switch self {
        case .meat:       return .red
        case .dairy:      return .blue
        case .vegetables: return .green
        case .fruits:     return .orange
        case .grains:     return .brown
        case .other:      return .gray
        }
    }
}

// MARK: - FridgeItemResponse helpers
extension FridgeItemResponse {
    var fridgeCategory: FridgeCategory {
        FridgeCategory.from(api: category)
    }

    var parsedExpiryDate: Date? {
        guard let exp = expiry_date else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: exp) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: exp) { return date }
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = simple.date(from: exp) { return date }
        simple.dateFormat = "yyyy-MM-dd"
        return simple.date(from: exp)
    }

    var daysUntilExpiry: Int? {
        guard let date = parsedExpiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: date).day
    }

    var freshness: Freshness {
        guard let days = daysUntilExpiry else { return .fresh }
        if days < 0 { return .expired }
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return .fresh
    }

    var displayEmoji: String {
        emoji ?? fridgeCategory.icon
    }
}


// MARK: - Fridge View
struct FridgeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var items: [FridgeItemResponse] = []
    @State private var selectedCategory: FridgeCategory? = nil
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var filteredItems: [FridgeItemResponse] {
        var result = items
        if let cat = selectedCategory {
            result = result.filter { $0.fridgeCategory == cat }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var groupedItems: [(FridgeCategory, [FridgeItemResponse])] {
        let grouped = Dictionary(grouping: filteredItems, by: { $0.fridgeCategory })
        return FridgeCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items.sorted { ($0.daysUntilExpiry ?? 999) < ($1.daysUntilExpiry ?? 999) })
        }
    }

    var expiringCount: Int {
        items.filter { $0.freshness == .critical || $0.freshness == .warning }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Загрузка...")
                            .padding(40)
                    } else {
                        if expiringCount > 0 {
                            expiryBanner
                        }

                        categoryFilter
                        statsRow

                        ForEach(groupedItems, id: \.0) { category, categoryItems in
                            categorySection(category: category, items: categoryItems)
                        }

                        if groupedItems.isEmpty {
                            emptyState
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Холодильник")
            .searchable(text: $searchText, prompt: "Найти продукт...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
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
                AddFridgeItemSheet(onAdded: { loadItems() })
            }
            .refreshable { await loadItemsAsync() }
            .task { await loadItemsAsync() }
            .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func loadItems() {
        Task { await loadItemsAsync() }
    }

    private func loadItemsAsync() async {
        do {
            let fetched = try await NetworkManager.shared.getFridgeItems()
            await MainActor.run {
                items = fetched
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func deleteItem(_ item: FridgeItemResponse) {
        Task {
            do {
                try await NetworkManager.shared.deleteFridgeItem(id: item.id)
                await MainActor.run {
                    items.removeAll { $0.id == item.id }
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    // MARK: - Expiry Banner
    private var expiryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(expiringCount) продуктов истекают")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("Нажмите чтобы посмотреть рецепты")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.white.opacity(0.6))
        }
        .padding(16)
        .background(
            LinearGradient(colors: [.orange, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "Все", icon: "tray.full.fill", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(FridgeCategory.allCases, id: \.self) { cat in
                    FilterChip(title: cat.rawValue, emoji: cat.icon, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatBubble(value: "\(items.count)", label: "Всего", icon: "refrigerator.fill", color: .blue)
            StatBubble(value: "\(items.filter { $0.freshness == .fresh }.count)", label: "Свежие", icon: "checkmark.circle.fill", color: .green)
            StatBubble(value: "\(expiringCount)", label: "Истекают", icon: "clock.badge.exclamationmark.fill", color: .orange)
        }
        .padding(.horizontal)
    }

    // MARK: - Category Section
    private func categorySection(category: FridgeCategory, items: [FridgeItemResponse]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(category.icon).font(.title3)
                Text(category.rawValue).font(.headline)
                Spacer()
                Text("\(items.count)")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(items) { item in
                    FridgeItemCard(item: item)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "refrigerator")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Холодильник пуст")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Добавьте продукты нажав +")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}


// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var emoji: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji = emoji {
                    Text(emoji).font(.caption)
                } else if let icon = icon {
                    Image(systemName: icon).font(.caption2)
                }
                Text(title).font(.caption).fontWeight(.semibold)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0.1 : 0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Stat Bubble
struct StatBubble: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
    }
}


// MARK: - Fridge Item Card
struct FridgeItemCard: View {
    let item: FridgeItemResponse

    var expiryText: String {
        guard let days = item.daysUntilExpiry else { return "Без срока" }
        if days < 0 { return "Просрочен \(abs(days)) дн." }
        if days == 0 { return "Истекает сегодня!" }
        if days == 1 { return "Ещё 1 день" }
        return "Ещё \(days) дн."
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(item.displayEmoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(item.fridgeCategory.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline).fontWeight(.medium)
                Text(item.quantity)
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: item.freshness.icon)
                    .font(.caption)
                    .foregroundStyle(item.freshness.color)
                Text(expiryText)
                    .font(.caption2)
                    .foregroundStyle(item.freshness.color)
                    .fontWeight(.medium)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    item.freshness == .critical || item.freshness == .expired
                        ? item.freshness.color.opacity(0.3) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}


// MARK: - Add Fridge Item Sheet
struct AddFridgeItemSheet: View {
    @Environment(\.dismiss) var dismiss
    var onAdded: () -> Void

    @State private var name = ""
    @State private var quantity = ""
    @State private var selectedCategory: FridgeCategory = .other
    @State private var expiryDate = Date().addingTimeInterval(7 * 86400)
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Button {
                        // barcode scan - future
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "barcode.viewfinder").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Сканировать штрихкод")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("Быстрое добавление по коду")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Или добавить вручную")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Название").font(.caption).foregroundStyle(.secondary)
                            TextField("Например: Куриная грудка", text: $name)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Количество").font(.caption).foregroundStyle(.secondary)
                            TextField("Например: 500г", text: $quantity)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Категория").font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(FridgeCategory.allCases, id: \.self) { cat in
                                    Button {
                                        selectedCategory = cat
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(cat.icon)
                                            Text(cat.rawValue).font(.caption).fontWeight(.medium)
                                        }
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedCategory == cat ? cat.color.opacity(0.15) : Color(.systemGray6))
                                        .foregroundStyle(selectedCategory == cat ? cat.color : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Срок годности").font(.caption).foregroundStyle(.secondary)
                            DatePicker("", selection: $expiryDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }

                    Button {
                        saveItem()
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text(isSaving ? "Сохранение..." : "Добавить").font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(name.isEmpty || isSaving ? Color(.systemGray4) : Color.blue)
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

    private func saveItem() {
        isSaving = true
        let formatter = ISO8601DateFormatter()
        let item = FridgeItemCreate(
            name: name,
            quantity: quantity.isEmpty ? "1 шт" : quantity,
            category: selectedCategory.apiValue,
            emoji: selectedCategory.icon,
            barcode: nil,
            expiry_date: formatter.string(from: expiryDate)
        )
        Task {
            do {
                _ = try await NetworkManager.shared.addFridgeItem(item)
                await MainActor.run {
                    isSaving = false
                    onAdded()
                    dismiss()
                }
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}
