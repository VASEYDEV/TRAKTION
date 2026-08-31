#if canImport(SwiftUI)
import SwiftUI
import TraktionUI

@main
struct TraktionApp: App {
    var body: some Scene {
        WindowGroup("TRAKTION") {
            CanvasPlaceholderView()
        }
    }
}
#endif
