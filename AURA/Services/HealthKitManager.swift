import SwiftUI
import HealthKit
import Combine
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    @Published var steps: Int = 0
    @Published var activeCalories: Double = 0
    @Published var sleepHours: Double = 0
    @Published var heartRate: Double = 0
    @Published var isAuthorized = false

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]

        store.requestAuthorization(toShare: [], read: types) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if granted { self.fetchAll() }
            }
        }
    }

    func fetchAll() {
        fetchSteps()
        fetchActiveCalories()
        fetchHeartRate()
        fetchSleep()
    }

    func fetchSteps() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            DispatchQueue.main.async {
                self.steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            }
        }
        store.execute(query)
    }

    func fetchActiveCalories() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            DispatchQueue.main.async {
                self.activeCalories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            }
        }
        store.execute(query)
    }

    func fetchHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            DispatchQueue.main.async {
                if let sample = samples?.first as? HKQuantitySample {
                    self.heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                }
            }
        }
        store.execute(query)
    }

    func fetchSleep() {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 20, sortDescriptors: [sort]) { _, samples, _ in
            DispatchQueue.main.async {
                let totalSeconds = samples?.compactMap { $0 as? HKCategorySample }
                    .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                              $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
                self.sleepHours = totalSeconds / 3600
            }
        }
        store.execute(query)
    }

    var stepsFormatted: String { "\(steps.formatted())" }
    var activeCaloriesFormatted: String { "\(Int(activeCalories))" }
    var sleepFormatted: String {
        let h = Int(sleepHours)
        let m = Int((sleepHours - Double(h)) * 60)
        return "\(h)ч \(m)м"
    }
    var heartRateFormatted: String { heartRate > 0 ? "\(Int(heartRate))" : "—" }

    var stepsProgress: Double { min(Double(steps) / 10000.0, 1.0) }
    var stepsGoalNote: String {
        let remaining = max(0, 10000 - steps)
        if remaining == 0 { return "🎉 Цель достигнута!" }
        return "Ещё \(remaining.formatted()) до цели"
    }

    var calorieAdjustment: Int {
        // Если больше 8000 шагов — добавить 200 ккал к норме
        if steps > 8000 { return 200 }
        if steps > 5000 { return 100 }
        return 0
    }

    var healthAdvice: String {
        if steps > 8000 && sleepHours >= 7 {
            return "Отличный день! Активность высокая — добавь \(calorieAdjustment) ккал белка к ужину"
        } else if sleepHours < 6 {
            return "Мало сна — избегай кофеина после 14:00 и добавь магний в рацион"
        } else if steps < 3000 {
            return "Мало движения сегодня — прогуляйся 20 минут после ужина"
        }
        return "Всё в норме! Продолжай в том же темпе"
    }
}
