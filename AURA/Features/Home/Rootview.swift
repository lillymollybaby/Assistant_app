import SwiftUI

struct RootView: View {
    @State private var showSplash = true
    @State private var isLoggedIn: Bool = AuthStorage.shared.token != nil
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "onboarding_completed")

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .zIndex(1)
            } else {
                if showOnboarding && !isLoggedIn {
                    OnboardingView {
                        withAnimation { showOnboarding = false }
                    }
                } else if isLoggedIn {
                    ContentView()
                        .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
                            isLoggedIn = false
                        }
                } else {
                    AuthView()
                        .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { _ in
                            isLoggedIn = true
                        }
                }
            }
        }
        .onAppear {
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.scheduleDinnerReminder()
            NotificationManager.shared.scheduleQuizReminder()
        }
    }
}

extension Notification.Name {
    static let didLogin = Notification.Name("didLogin")
    static let didLogout = Notification.Name("didLogout")
}
