import HealthKit

final class MindfulnessHealthStore {
    private let healthStore = HKHealthStore()
    private let mindfulType = HKCategoryType(.mindfulSession)

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        Task {
            try? await healthStore.requestAuthorization(
                toShare: [mindfulType],
                read: []
            )
        }
    }

    func saveSession(from startDate: Date, to endDate: Date) {
        guard HKHealthStore.isHealthDataAvailable(),
              endDate.timeIntervalSince(startDate) >= 1 else { return }

        Task {
            do {
                try await healthStore.requestAuthorization(
                    toShare: [mindfulType],
                    read: []
                )
                guard healthStore.authorizationStatus(for: mindfulType) == .sharingAuthorized else {
                    return
                }

                let sample = HKCategorySample(
                    type: mindfulType,
                    value: HKCategoryValue.notApplicable.rawValue,
                    start: startDate,
                    end: endDate
                )
                healthStore.save(sample) { _, _ in }
            } catch {
                return
            }
        }
    }
}
