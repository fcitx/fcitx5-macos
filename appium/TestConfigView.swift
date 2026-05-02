import FcitxConfigUI
import SwiftUI

struct TestConfigView: View {
  var body: some View {
    VStack {
      Button("Global Config") {
        NSApp.mainWindow?.close()
        ConfigWindowController.openWindow("global", GlobalConfigController.self)
      }
      Button("Input Method") {}
      Button("Theme") {}
      Button("Addon") {}
      Button("Advanced") {}
      Button("About") {}
    }
  }
}
