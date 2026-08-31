#if canImport(SwiftUI)
  import SwiftUI
  import TraktionUI

  @main
  struct TRAKTIONApp: App {
    var body: some Scene {
      WindowGroup {
        TraktionWorkspaceView()
      }
    }
  }
#else
  import Foundation

  @main
  enum TRAKTIONApp {
    static func main() {
      print("The TRAKTION native shell requires macOS or iOS.")
    }
  }
#endif
