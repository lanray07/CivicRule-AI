import Foundation
import Vision
import PDFKit
import UIKit

struct ExtractedDocument: Sendable { let pages: [String]; let data: Data; let type: String }

enum DocumentService {
    static func extract(data: Data, isPDF: Bool) async throws -> ExtractedDocument {
        try await Task.detached(priority: .userInitiated) {
            guard data.count <= 20_000_000 else { throw CivicError.message("Choose a document smaller than 20 MB.") }
            if isPDF {
                guard let pdf = PDFDocument(data: data), !pdf.isLocked else { throw CivicError.message("This PDF is locked or unreadable.") }
                guard pdf.pageCount <= 50 else { throw CivicError.message("Please import no more than 50 pages at a time.") }
                var pages: [String] = []
                for index in 0..<pdf.pageCount {
                    guard let page = pdf.page(at: index) else { continue }
                    if let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { pages.append(text) }
                    else {
                        let image = page.thumbnail(of: CGSize(width: 1600, height: 2200), for: .mediaBox)
                        pages.append(try ocr(image))
                    }
                }
                return ExtractedDocument(pages: pages, data: data, type: "pdf")
            }
            guard let image = UIImage(data: data) else { throw CivicError.message("This image cannot be opened.") }
            return ExtractedDocument(pages: [try ocr(image)], data: data, type: "image")
        }.value
    }

    private static func ocr(_ image: UIImage) throws -> String {
        // Rasterise upright so camera EXIF orientation does not rotate recognition input.
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 2200 / max(1, longest))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let cgImage = upright.cgImage else { throw CivicError.message("Could not read this image.") }
        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    static func actionLines(_ pages: [String]) -> [(Int, String)] {
        pages.enumerated().flatMap { index, text in
            text.components(separatedBy: .newlines).filter { line in
                let lower = line.lowercased()
                return ["must ", "required", "deadline", "expires", "expiry", "respond", "submit"].contains { lower.contains($0) }
            }.prefix(10).map { (index + 1, $0) }
        }
    }
}

