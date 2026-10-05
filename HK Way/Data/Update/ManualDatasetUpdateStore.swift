import Foundation

struct ManualDatasetUpdateStore {

    private let updateDayKey = "manualDatasetUpdateDay"
    private let updateCountKey = "manualDatasetUpdateCount"
    private let lastUpdatedKey = "manualDatasetLastUpdatedAt"
    private let dailyLimit = 3

    var remainingUpdatesToday: Int {
        max(0, dailyLimit - updatesToday)
    }

    var lastUpdatedAt: Date? {
        UserDefaults.standard.object(
            forKey: lastUpdatedKey
        ) as? Date
    }

    @discardableResult
    func beginManualUpdate() -> Bool {
        let defaults = UserDefaults.standard
        let today = dayIdentifier(for: .now)
        let storedDay = defaults.string(forKey: updateDayKey)

        let currentCount: Int

        if storedDay == today {
            currentCount = defaults.integer(forKey: updateCountKey)
        } else {
            currentCount = 0
            defaults.set(today, forKey: updateDayKey)
        }

        guard currentCount < dailyLimit else {
            return false
        }

        defaults.set(currentCount + 1, forKey: updateCountKey)
        return true
    }

    func recordSuccessfulUpdate() {
        UserDefaults.standard.set(
            Date.now,
            forKey: lastUpdatedKey
        )
    }

    private var updatesToday: Int {
        let defaults = UserDefaults.standard

        guard defaults.string(forKey: updateDayKey) == dayIdentifier(for: .now) else {
            return 0
        }

        return defaults.integer(forKey: updateCountKey)
    }

    private func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
