import XCTest
import SwiftData
@testable import CivicRule

final class CivicRuleTests: XCTestCase {
    func testTemplatesAreInvestigationPrompts() {
        XCTAssertTrue(BusinessTemplates.checks(for: "Café").contains { $0.0 == "Food" })
        XCTAssertFalse(BusinessTemplates.checks(for: "Barber").contains { $0.0 == "Food" })
    }
    func testVoiceReminderIntentRequiresAction() {
        XCTAssertEqual(VoiceIntentRouter().resolveIntent("Add that deadline"), .reminder)
        XCTAssertEqual(VoiceIntentRouter().resolveIntent("What's the deadline?"), .question)
        XCTAssertEqual(VoiceIntentRouter().resolveIntent("Show me the original wording"), .original)
    }
    func testActionExtractionPreservesPageAndWording() {
        let result = DocumentService.actionLines(["Welcome", "You must respond by 3 April.\nReference: 123"])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.0, 2)
        XCTAssertEqual(result.first?.1, "You must respond by 3 April.")
    }
    @MainActor func testSwiftDataPersistenceRetainsBusinessIdentity() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Business.self, ChecklistItem.self, Permit.self, SavedAnswer.self, Notice.self, configurations: config)
        let context = container.mainContext
        let business = Business(name: "Test", kind: "Barber", address: "User address", nation: "England", authority: "")
        context.insert(business)
        let item = ChecklistItem(businessID: business.id, title: "Verify use", category: "Planning")
        context.insert(item); try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChecklistItem>()).first?.businessID, business.id)
        XCTAssertEqual(item.status, "Not Checked")
    }
}

