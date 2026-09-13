import Foundation
import SwiftData

@Model final class Business {
    @Attribute(.unique) var id: UUID
    var name: String
    var kind: String
    var address: String
    var nation: String
    var authority: String
    var activities: String
    var hours: String
    var created: Date
    init(name: String, kind: String, address: String, nation: String, authority: String, activities: String = "", hours: String = "") {
        id = UUID(); self.name = name; self.kind = kind; self.address = address
        self.nation = nation; self.authority = authority; self.activities = activities
        self.hours = hours; created = .now
    }
}

enum CheckStatus: String, CaseIterable, Codable {
    case notChecked = "Not Checked", attention = "Needs Attention", progress = "In Progress"
    case confirmed = "User Confirmed", completed = "Completed"
}

@Model final class ChecklistItem {
    @Attribute(.unique) var id: UUID
    var businessID: UUID
    var title: String
    var category: String
    var status: String
    var sourceURL: String
    var notes: String
    init(businessID: UUID, title: String, category: String, sourceURL: String = "") {
        id = UUID(); self.businessID = businessID; self.title = title; self.category = category
        status = CheckStatus.notChecked.rawValue; self.sourceURL = sourceURL; notes = ""
    }
}

enum PermitStatus: String, CaseIterable {
    case researching = "Researching", required = "Required", applying = "Applying", submitted = "Submitted"
    case approved = "Approved", renewalDue = "Renewal Due", expired = "Expired"
    case notRequired = "Not Required — User Confirmed"
}

@Model final class Permit {
    @Attribute(.unique) var id: UUID
    var businessID: UUID
    var name: String
    var authority: String
    var reference: String
    var status: String
    var applicationDate: Date?
    var issueDate: Date?
    var expiryDate: Date?
    var renewalDate: Date?
    var notes: String
    init(businessID: UUID, name: String, authority: String, reference: String = "", expiryDate: Date? = nil) {
        id = UUID(); self.businessID = businessID; self.name = name; self.authority = authority
        self.reference = reference; self.expiryDate = expiryDate; status = PermitStatus.researching.rawValue; notes = ""
    }
}

@Model final class SavedAnswer {
    @Attribute(.unique) var id: UUID
    var businessID: UUID
    var question: String
    var payload: Data
    var savedAt: Date
    init(businessID: UUID, answer: RegulatoryAnswer) throws {
        id = UUID(); self.businessID = businessID; question = answer.question
        payload = try JSONEncoder().encode(answer); savedAt = .now
    }
    var answer: RegulatoryAnswer? { try? JSONDecoder().decode(RegulatoryAnswer.self, from: payload) }
}

@Model final class Notice {
    @Attribute(.unique) var id: UUID
    var businessID: UUID
    var title: String
    var pages: [String]
    @Attribute(.externalStorage) var original: Data
    var fileType: String
    var created: Date
    init(businessID: UUID, title: String, pages: [String], original: Data, fileType: String) {
        id = UUID(); self.businessID = businessID; self.title = title; self.pages = pages
        self.original = original; self.fileType = fileType; created = .now
    }
}

struct OfficialSource: Codable, Identifiable {
    var id: String
    var authority: String
    var title: String
    var jurisdiction: String
    var url: String
    var publicationDate: String?
    var checkedAt: String
    var section: String
    var excerpt: String
    var contentHash: String
}

struct RegulatoryAnswer: Codable, Identifiable {
    var id: String
    var question: String
    var shortAnswer: String
    var checks: [String]
    var sources: [OfficialSource]
    var confidence: String
    var reason: String
    var limitations: [String]
    var status: String
    var answeredAt: String
}

struct QuestionRequest: Codable {
    var question: String
    var nation: String
    var authority: String
    var businessType: String
    var activities: String
}

enum BusinessTemplates {
    static let kinds = ["Barber", "Hair Salon", "Beauty Salon", "Café", "Restaurant", "Takeaway", "Retail Shop", "Landscaper", "Builder", "Electrician", "Plumber", "Home Business", "Personal Trainer", "Gym", "Market Trader", "Food Truck", "Office"]
    static func checks(for kind: String) -> [(String, String)] {
        var items = [("Planning", "Verify the existing authorised use"), ("Licensing", "Ask which licences apply to your activities"), ("Signage", "Check proposed signage with the authority"), ("Waste", "Investigate commercial waste arrangements"), ("Premises", "Review access, alterations and fire safety"), ("Opening hours", "Check any recorded operating conditions")]
        if ["Café", "Restaurant", "Takeaway", "Food Truck"].contains(kind) {
            items.append(("Food", "Investigate food-business registration and hygiene requirements"))
        }
        return items
    }
}

