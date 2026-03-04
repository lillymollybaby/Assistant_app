# 📁 Project Structure

AURA follows a clean, modular architecture using **Feature-based organization** with shared Services and Utils.

## Directory Layout

```
AURA/
├── AURAApp.swift                 # App entry point, app lifecycle
├── Info.plist                    # App configuration
├── Assets.xcassets/              # Images, colors, icons
│
├── Features/                      # Feature modules (one folder per feature)
│   ├── Auth/                      # Authentication & Onboarding
│   │   ├── AuthView.swift
│   │   └── Onboardingview.swift
│   │
│   ├── Home/                      # Main app screen (dashboard)
│   │   ├── ContentView.swift
│   │   └── Rootview.swift
│   │
│   ├── Cinema/                    # Movie tracking (Letterboxd sync, reviews)
│   │   ├── CinemaView.swift
│   │   ├── MovieDetailView.swift
│   │   ├── MovieQuizView.swift
│   │   └── PlatformConnectSheet.swift
│   │
│   ├── Food/                      # Meal logging (photo analysis, nutrition)
│   │   ├── FoodView.swift
│   │   └── ScanDecideView.swift
│   │
│   ├── Languages/                 # Language learning (vocabulary, lessons)
│   │   └── LanguagesView.swift
│   │
│   ├── Logistics/                 # Route planning (2GIS integration)
│   │   └── LogisticsView.swift
│   │
│   └── Profile/                   # User profile & settings
│       └── ProfileView.swift
│
├── Services/                      # Shared business logic & API clients
│   ├── APIConfig.swift            # Secure API key management (no hardcoded keys!)
│   ├── NetworkManager.swift       # HTTP client, API requests
│   ├── NotificationManager.swift  # Push notifications with per-category toggles
│   ├── HealthKitManager.swift     # HealthKit integration
│   └── LetterboxdSyncService.swift# Letterboxd RSS sync
│
└── Utils/                         # Utilities & helpers
    └── ErrorHandler.swift
```

## Architecture Principles

### 1. **Feature-Based Organization**
- Each feature is independent and self-contained
- Easy to add/remove features
- Clear responsibility boundaries

### 2. **Separation of Concerns**
- **Features** = UI views, user interactions
- **Services** = Business logic, API calls, external integrations  
- **Utils** = Helper functions, common utilities

### 3. **Dependency Management**
- Services are accessed via singletons (e.g., `NetworkManager.shared`)
- Features depend on Services, not the other way around
- No circular dependencies

### 4. **Security**
- No hardcoded API keys in source code
- API keys stored in `.env` (Backend) and fetched at runtime
- Use `APIConfig.swift` to manage credentials securely

## Key Services

| Service | Purpose |
|---------|---------|
| `NetworkManager` | All HTTP requests (TMDB, Gemini, 2GIS, custom API) |
| `NotificationManager` | Local & remote push notifications with toggles |
| `HealthKitManager` | Steps, calories, workouts from phone |
| `LetterboxdSyncService` | Sync watched movies from Letterboxd RSS |
| `APIConfig` | Secure credential management (no hardcoded keys) |

## Adding a New Feature

1. Create folder: `AURA/Features/NewFeature/`
2. Add view file(s): `AURA/Features/NewFeature/NewFeatureView.swift`
3. Import services as needed: `import NetworkManager`, `import NotificationManager`
4. Add to `ContentView.swift` navigation

Example:
```swift
import SwiftUI

struct PhotoFeatureView: View {
    let networkManager = NetworkManager.shared
    
    var body: some View {
        VStack {
            Text("Photo Feature")
        }
    }
}
```

## File Naming Conventions

- **Views**: `*View.swift` (e.g., `ProfileView.swift`, `MovieDetailView.swift`)
- **Services**: `*Manager.swift` or `*Service.swift` (e.g., `NetworkManager.swift`)
- **Utils**: `*Handler.swift` or descriptive name (e.g., `ErrorHandler.swift`)
- **CamelCase** for file names (no spaces, consistent casing)

## Updating in Xcode

After cloning or after structural changes:

1. Open project in **Xcode**: `AURA.xcodeproj`
2. Xcode may prompt to update file references (click **Fix**)
3. Build & run (Cmd+R)

If file references are missing:
1. **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. Select missing file in Xcode Navigator panel
3. **File Inspector** → check "Target Membership" for "AURA"

---

**Last Updated:** March 3, 2026  
**Architecture:** Feature-Based MVVM  
**iOS Minimum:** 14.0
