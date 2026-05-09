import FcitxConfigUI
import SwiftUI

struct TestConfigView: View {
  var body: some View {
    VStack {
      Button("Input Method") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("im", InputMethodConfigController.self)
      }.accessibilityIdentifier("Input Method")
      Button("Global Config") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("global", GlobalConfigController.self)
      }.accessibilityIdentifier("Global Config")
      Button("Theme") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("theme", ThemeEditorController.self)
      }.accessibilityIdentifier("Theme")
      Button("Advanced") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("advanced", AdvancedController.self)
      }.accessibilityIdentifier("Advanced")
    }
  }
}
