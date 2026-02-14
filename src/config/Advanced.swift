import Fcitx
import Logging
import SwiftUI

class AdvancedController: ConfigWindowController {
  let view = AdvancedView()

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: styleMask,
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Advanced", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
    window.titlebarAppearsTransparent = true
    attachToolbar(window)
  }

  override func refresh() {
    view.refresh()
  }
}

private struct Addon: Codable, Identifiable {
  let name: String
  let id: String
  let comment: String
}

private struct Category: Codable, Identifiable {
  let name: String
  let id: Int
  let addons: [Addon]
}

private let dataManagerId = "\(UUID())"

struct AdvancedView: View {
  @ObservedObject private var viewModel = AdvancedViewModel()
  @ObservedObject private var manager = ConfigManager()
  @State private var selectedItem = dataManagerId

  init() {
    refresh()
  }

  func refresh() {
    viewModel.load()
    manager.reload()  // Refresh macosfrontend config when click hide in status bar.
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedItem) {
        Text("Data manager").id(dataManagerId)
        ForEach(viewModel.categories) { category in
          Section(header: Text(category.name)) {
            ForEach(category.addons) { addon in
              let text = Text(addon.name)
              if !addon.comment.isEmpty {
                text.tooltip(addon.comment)
              } else {
                text
              }
            }
          }
        }
      }
    } detail: {
      VStack {
        if selectedItem == dataManagerId {
          ScrollView {
            DataView()
          }
          HStack {
            Spacer()
            Button {
              FcitxInputController.closeWindow("advanced")
            } label: {
              Text("Close")
            }
          }.padding()
        } else {
          ScrollView {
            BasicConfigView(
              config: manager.config, value: manager.value, onUpdate: { manager.set($0) }
            )
            .padding()
          }
          FooterView(
            manager: manager,
            onClose: {
              FcitxInputController.closeWindow("advanced")
            })
        }
      }.padding([.top], 1)
    }.onChange(of: selectedItem) { newValue in
      if newValue != dataManagerId {
        manager.uri = "fcitx://config/addon/\(selectedItem)"
      }
    }
  }
}

class AdvancedViewModel: ObservableObject {
  @Published fileprivate var categories = [Category]()

  func load() {
    categories = decodeJSON(String(Fcitx.getAddons()), [Category]())
  }
}
