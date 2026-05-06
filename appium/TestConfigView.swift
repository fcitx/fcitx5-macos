import FcitxConfigUI
import SwiftUI

struct TestConfigView: View {
  var body: some View {
    VStack {
      Button("Input Method") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("im", InputMethodConfigController.self)
      }
      Button("Global Config") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("global", GlobalConfigController.self)
      }
      Button("Theme") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("theme", ThemeEditorController.self)
      }
      Button("Advanced") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("advanced", AdvancedController.self)
      }
    }
  }
}
