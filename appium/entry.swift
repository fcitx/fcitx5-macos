import Fcitx
import SwiftUI

class TestAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    start_fcitx_thread("")
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}

@main
struct TestApp: App {
  @NSApplicationDelegateAdaptor(TestAppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      TestConfigView()
    }
  }
}
