import SwiftUI

// MARK: - App Error (обёртка для показа в UI)
struct AppError: Identifiable {
    let id = UUID()
    let message: String
    let isNoInternet: Bool

    init(_ error: Error) {
        if let api = error as? APIError {
            self.message = api.errorDescription ?? "Неизвестная ошибка"
            self.isNoInternet = api.isNoInternet
        } else {
            self.message = error.localizedDescription
            self.isNoInternet = false
        }
    }

    init(_ message: String, isNoInternet: Bool = false) {
        self.message = message
        self.isNoInternet = isNoInternet
    }
}

// MARK: - Error Alert Modifier
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: AppError?

    func body(content: Content) -> some View {
        content
            .alert(
                error?.isNoInternet == true ? "Нет интернета" : "Ошибка",
                isPresented: .constant(error != nil),
                presenting: error
            ) { _ in
                Button("OK") { error = nil }
            } message: { err in
                Text(err.message)
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}

// MARK: - No Internet Banner
struct NoInternetBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Нет подключения")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text("Данные могут быть устаревшими")
                    .font(.caption).foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange)
        .cornerRadius(12)
        .padding(.horizontal).padding(.top, 4)
    }
}
