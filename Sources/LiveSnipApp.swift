import AppKit

@main
enum LiveSnipApp {
    @MainActor
    static func main() {
        // `LiveSnip --ocr image.png` prints the text in an image, for scripting and testing.
        let arguments = CommandLine.arguments
        if arguments.count == 3, arguments[1] == "--ocr" {
            let url = URL(fileURLWithPath: arguments[2])
            Task {
                do {
                    print(try await LiveText.recognize(imageAt: url))
                    exit(0)
                } catch {
                    FileHandle.standardError.write(Data("LiveSnip: \(error.localizedDescription)\n".utf8))
                    exit(1)
                }
            }
            dispatchMain()
        }

        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
