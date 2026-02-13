import SwiftUI

struct SplitConfigView: View {
  private let key: String
  private let options: [String]
  @ObservedObject private var manager = ConfigManager()
  @State private var dummyText = ""

  init(uri: String, key: String) {
    self.key = key
    self.options = (getConfig(uri)["Children"] as? [[String: Any]] ?? []).compactMap {
      $0["Description"] as? String
    }
    manager.index = 0
    manager.uri = uri
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $manager.index) {
        ForEach(0..<options.count, id: \.self) { i in
          Text(options[i])
        }
      }
    } detail: {
      if manager.uri == webpanelUri {
        TextField(NSLocalizedString("Type here to preview style", comment: ""), text: $dummyText)
          .padding([.top, .leading, .trailing])
      }
      ScrollView {
        BasicConfigView(config: manager.config, value: manager.value, onUpdate: { manager.set($0) })
          .padding()
      }.padding([.top], 1)  // Cannot be 0 otherwise content overlaps with title bar.
      FooterView(
        manager: manager,
        onClose: {
          FcitxInputController.controllers[key]?.window?.performClose(_: nil)
        })
    }
  }
}
