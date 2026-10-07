import CxxFrontend
import Fcitx
import SwiftUI

class TestAppDelegate: NSObject, NSApplicationDelegate {
  private var sigintSource: DispatchSourceSignal!
  private var sigtermSource: DispatchSourceSignal!

  private func installSignalHandlers() {
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)

    sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    sigtermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)

    sigintSource.setEventHandler {
      Task { @MainActor in
        NSApp.terminate(nil)
      }
    }
    sigtermSource.setEventHandler {
      Task { @MainActor in
        NSApp.terminate(nil)
      }
    }

    sigintSource.resume()
    sigtermSource.resume()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    installSignalHandlers()
    start_fcitx_thread("")
    // The production input controller keeps this in sync. The test app has no
    // input controller, so initialize it from the test profile explicitly.
    _ = get_current_group_layout()
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
