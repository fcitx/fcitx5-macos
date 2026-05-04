import SwiftUI

struct SplitConfigView: View {
  private let key: String
  private let options: [String]
  private let descriptions: [String]
  @ObservedObject private var manager = ConfigManager()
  @ObservedObject private var fontVM = FontVM.shared
  @State private var dummyText = ""

  init(uri: String, key: String) {
    self.key = key
    let children = getConfig(uri)["Children"] as? [[String: Any]] ?? []
    self.options = children.compactMap {
      $0["Option"] as? String
    }
    self.descriptions = children.compactMap {
      $0["Description"] as? String
    }
    manager.index = 0
    manager.uri = uri
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $manager.index) {
        ForEach(0..<options.count, id: \.self) { i in
          Text(descriptions[i]).accessibilityIdentifier(options[i])
        }
      }
    } detail: {
      if manager.uri == webpanelUri {
        if manager.config["Option"] as? String == "Font" && fontVM.hasNewFonts {
          GroupBox {
            HStack {
              Text("Restart process to load new fonts")
              Button {
                ConfigWindowController.closeWindow(key)
                DispatchQueue.main.async {
                  restartProcess()
                }
              } label: {
                Image(systemName: "arrow.clockwise")
              }
            }.frame(maxWidth: .infinity)
          }.padding([.leading, .trailing])
        }
        TextField(NSLocalizedString("Type here to preview style", comment: ""), text: $dummyText)
          .padding([.top, .leading, .trailing])
      }
      ScrollView {
        BasicConfigView(
          config: manager.config, value: $manager.value, onUpdate: { manager.set($0) }
        )
        .padding()
      }.padding([.top], 1)  // Cannot be 0 otherwise content overlaps with title bar.
      FooterView(
        manager: manager,
        onClose: {
          ConfigWindowController.closeWindow(key)
        })
    }
  }
}
