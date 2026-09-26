import AppKit

@main
enum LiveSnipApp {
    @MainActor
    static func main() {
        let arguments = CommandLine.arguments
        // The fresh permission check that ScreenRecording.recheck() runs in a new process.
        if arguments.count == 2, arguments[1] == ScreenRecording.freshCheckArgument {
            exit(CGPreflightScreenCaptureAccess() ? 0 : 1)
        }

        // `LiveSnip --ocr image.png` prints the text in an image, for scripting and testing.
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
