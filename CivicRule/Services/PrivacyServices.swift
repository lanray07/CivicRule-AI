import Foundation
import LocalAuthentication
import Security
import UserNotifications

enum PrivacyService {
    static func authenticate() async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your business records")
    }
}

enum KeychainService {
    static func read(_ key: String) throws -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CivicRule", kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data else { throw CivicError.message("Could not read the secure credential.") }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ value: String, key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CivicRule", kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var insert = query
        insert[kSecValueData as String] = Data(value.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else { throw CivicError.message("Could not store the secure credential.") }
    }
    static func deleteAll() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "CivicRule"] as CFDictionary)
    }
}

struct ReminderService {
    func addReminder(id: UUID, name: String, date: Date, daysBefore: Int) async throws {
        let center = UNUserNotificationCenter.current()
        guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { throw CivicError.message("Notifications are disabled. Enable them in Settings to add reminders.") }
        guard let fire = Calendar.current.date(byAdding: .day, value: -daysBefore, to: date), fire > .now else { throw CivicError.message("Choose a reminder time in the future.") }
        let content = UNMutableNotificationContent()
        content.title = "A recorded permit date is approaching"
        content.body = "\(name) is recorded as due on \(date.formatted(date: .abbreviated, time: .omitted)). Check your original document."
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        try await center.add(UNNotificationRequest(identifier: "\(id)-\(daysBefore)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
    func removeReminders(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [90, 60, 30, 14, 7, 1, 0].map { "\(id)-\($0)" })
    }
}

