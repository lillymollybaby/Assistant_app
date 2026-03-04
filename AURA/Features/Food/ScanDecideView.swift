import SwiftUI
import PhotosUI

// MARK: - Scan Result Model
struct ScanResult: Codable {
    // Поля нового бэкенда
    let product_name: String?
    let verdict: String?           // "safe" | "caution" | "avoid"
    let score: Double?             // 0–10, где 10 = очень здорово
    let warnings: [String]?        // ["Содержит E621", "Много сахара"]
    let positives: [String]?       // ["Нет трансжиров", "Высокий белок"]
    let summary: String?           // краткое заключение AI

    // Поля старого бэкенда (оставляем для совместимости)
    let name: String?
    let calories: Double?
    let proteins: Double?
    let fats: Double?
    let carbs: Double?
    let serving_size: String?
    let ingredients_summary: String?

    // Вспомогательные computed properties
    var displayName: String {
        product_name ?? name ?? "Продукт"
    }

    var verdictColor: VerdictColor {
        switch verdict {
        case "safe":    return .safe
        case "caution": return .caution
        case "avoid":   return .avoid
        default:
            // фоллбэк по калориям если verdict отсутствует
            let cal = calories ?? 0
            if cal < 200 { return .safe }
            if cal < 400 { return .caution }
            return .avoid
        }
    }
}

enum VerdictColor {
    case safe, caution, avoid

    var color: Color {
        switch self {
        case .safe:    return .green
        case .caution: return .orange
        case .avoid:   return .red
        }
    }

    var label: String {
        switch self {
        case .safe:    return "Можно есть"
        case .caution: return "Осторожно"
        case .avoid:   return "Лучше избегать"
        }
    }

    var icon: String {
        switch self {
        case .safe:    return "checkmark.circle.fill"
        case .caution: return "exclamationmark.circle.fill"
        case .avoid:   return "xmark.circle.fill"
        }
    }
}

// MARK: - Scan & Decide View
struct ScanDecideView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var scanResult: ScanResult?
    @State private var isScanning = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "barcode.viewfinder")
                                    .foregroundColor(.white)
                                    .font(.title3)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Scan & Decide").font(.title2).bold()
                                Text("AI анализ состава продукта").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                    }
                    .padding(.horizontal)

                    // Photo picker
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemGray6))
                                .frame(height: 200)

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.green, lineWidth: 2)
                                    )
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.system(size: 48))
                                        .foregroundColor(.green.opacity(0.7))
                                    Text("Сфотографируй этикетку")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("AI найдёт вредные добавки, сахар и трансжиры")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }

                            if isScanning {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.black.opacity(0.5))
                                    .frame(height: 200)
                                VStack(spacing: 10) {
                                    ProgressView().tint(.white)
                                    Text("Gemini анализирует...").font(.subheadline).foregroundColor(.white)
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
                                await scanProduct(imageData: data)
                            }
                        }
                    }

                    // Result
                    if let result = scanResult {
                        ScanResultCard(result: result)
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal)
                    }

                    // Tips
                    if scanResult == nil && !isScanning {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("На что обращать внимание").font(.headline)
                            TipRow(icon: "exclamationmark.triangle.fill", color: .red, tip: "E621, E631 — усилители вкуса")
                            TipRow(icon: "exclamationmark.triangle.fill", color: .orange, tip: "Трансжиры — hydrogenated oil")
                            TipRow(icon: "drop.fill", color: .blue, tip: "Натрий > 600мг на порцию")
                            TipRow(icon: "cube.fill", color: .purple, tip: "Сахар в первых 3 ингредиентах")
                            TipRow(icon: "checkmark.circle.fill", color: .green, tip: "Менее 5 ингредиентов — хорошо")
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 30)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Scan & Decide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                if scanResult != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Сканировать ещё") {
                            selectedImage = nil
                            scanResult = nil
                            selectedItem = nil
                        }
                    }
                }
            }
        }
    }

    func scanProduct(imageData: Data) async {
        isScanning = true
        errorMessage = ""
        do {
            scanResult = try await NetworkManager.shared.scanProduct(imageData: imageData)
        } catch {
            errorMessage = "Не удалось проанализировать продукт"
        }
        isScanning = false
    }
}

// MARK: - Scan Result Card
struct ScanResultCard: View {
    let result: ScanResult

    var vc: VerdictColor { result.verdictColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Название + вердикт
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(vc.color.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: vc.icon)
                        .foregroundColor(vc.color)
                        .font(.title3)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.displayName)
                        .font(.title3).bold().lineLimit(2)
                    if let serving = result.serving_size {
                        Text("Порция: \(serving)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(vc.label)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(vc.color)
                    if let score = result.score {
                        Text("\(Int(score))/10")
                            .font(.title3).bold().foregroundColor(vc.color)
                    } else if let cal = result.calories {
                        Text("\(Int(cal))")
                            .font(.system(size: 24, weight: .bold)).foregroundColor(vc.color)
                        Text("ккал").font(.caption).foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Предупреждения
            if let warnings = result.warnings, !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Осторожно", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.orange)
                    ForEach(warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red).font(.caption)
                            Text(warning)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.07))
                .cornerRadius(12)
            }

            // Плюсы
            if let positives = result.positives, !positives.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Хорошее", systemImage: "checkmark.seal.fill")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(.green)
                    ForEach(positives, id: \.self) { positive in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green).font(.caption)
                            Text(positive)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.07))
                .cornerRadius(12)
            }

            // Macros (если есть от старого бэкенда)
            if result.proteins != nil || result.carbs != nil || result.fats != nil {
                Divider()
                HStack(spacing: 0) {
                    MacroStatScan(value: Int(result.proteins ?? 0), label: "Белки", unit: "г", color: .blue)
                    Divider().frame(height: 40)
                    MacroStatScan(value: Int(result.carbs ?? 0), label: "Углеводы", unit: "г", color: .orange)
                    Divider().frame(height: 40)
                    MacroStatScan(value: Int(result.fats ?? 0), label: "Жиры", unit: "г", color: .purple)
                }
            }

            // AI заключение
            if let summary = result.summary ?? result.ingredients_summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Заключение AI", systemImage: "sparkles")
                        .font(.subheadline).fontWeight(.semibold)
                    Text(summary)
                        .font(.caption).foregroundColor(.secondary).lineSpacing(3)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: vc.color.opacity(0.12), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(vc.color.opacity(0.2), lineWidth: 1.5)
        )
    }
}

struct MacroStatScan: View {
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

struct TipRow: View {
    let icon: String
    let color: Color
    let tip: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color).font(.subheadline).frame(width: 20)
            Text(tip).font(.subheadline).foregroundColor(.secondary)
        }
    }
}
