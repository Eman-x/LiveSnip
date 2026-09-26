import Foundation
import VisionKit

/// Reads text with VisionKit's ImageAnalyzer, the engine behind Live Text, so it recognizes the
/// same languages Live Text does in the user's preferred languages (English and Arabic here).
enum LiveText {
    private static let analyzer = ImageAnalyzer()

    static func recognize(imageAt url: URL) async throws -> String {
        let analysis = try await analyzer.analyze(imageAt: url, orientation: .up, configuration: .init([.text]))
        return analysis.transcript
    }
}
