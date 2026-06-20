import Fcitx
import SwiftUI

private func signalHandler(signal: Int32) {
  Task { @MainActor in
    NSApp.terminate(nil)
  }
}

class TestAppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    signal(SIGINT, signalHandler)
    signal(SIGTERM, signalHandler)
    start_fcitx_thread("")
  }

  func applicationWillTerminate(_ notification: Notification) {
    stop_fcitx_thread()
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
