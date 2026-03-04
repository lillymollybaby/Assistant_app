import SwiftUI

// MARK: - Root Tab View (iOS 18 sidebarAdaptable style)
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Logistics", systemImage: "location.fill") {
                LogisticsView()
            }
            Tab("Languages", systemImage: "character.book.closed.fill") {
                LanguagesView()
            }
            Tab("Cinema", systemImage: "film.fill") {
                CinemaView()
            }
            Tab("Food", systemImage: "fork.knife") {
                FoodView()
            }
            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
