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
    // TODO
  }
}

class LegacyAdvancedController: ConfigWindowController {
  let view = LegacyAdvancedView()

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

// non-addon
private let dataManager = NSLocalizedString("Data manager", comment: "")

struct LegacyAdvancedView: View {
  @ObservedObject private var viewModel = LegacyAdvancedViewModel()

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selected) {
        ForEach([dataManager], id: \.self) { id in
          Text(id)
        }
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
        if let selected = viewModel.selected {
          if selected == dataManager {
            ScrollView {
              DataView()
            }
          } else if let config = viewModel.config {
            ScrollView {
              buildView(config: config).padding([.leading, .trailing])
            }
            legacyfooter(
              reset: {
                config.resetToDefault()
              },
              apply: {
                Fcitx.setConfig("fcitx://config/addon/\(selected)", config.encodeValue())
              },
              close: {
                FcitxInputController.closeWindow("advancedLegacy")
              })
          }
        }
      }.padding([.top], 1)
    }
  }

  func refresh() {
    viewModel.load()
  }
}

class LegacyAdvancedViewModel: ObservableObject {
  @Published fileprivate var categories = [Category]()
  @Published var selected: String? = dataManager {
    didSet {
      if let selected = selected,
        selected != dataManager
      {
        do {
          config = try getConfig(addon: selected)
        } catch {
          FCITX_ERROR("Couldn't load addon config: \(error)")
        }
      }
    }
  }
  @Published var config: Config?

  func load() {
    do {
      let jsonStr = String(Fcitx.getAddons())
      if let jsonData = jsonStr.data(using: .utf8) {
        categories = try JSONDecoder().decode([Category].self, from: jsonData)
      } else {
        FCITX_ERROR("Couldn't decode addon config: not UTF-8")
      }
    } catch {
      FCITX_ERROR("Couldn't load addon config: \(error)")
    }
  }
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
    let jsonStr = String(Fcitx.getAddons())
    if let jsonData = jsonStr.data(using: .utf8) {
      do {
        categories = try JSONDecoder().decode([Category].self, from: jsonData)
      } catch {
        FCITX_ERROR("Couldn't load addon config: \(error)")
      }
    } else {
      FCITX_ERROR("Couldn't decode addon config: not UTF-8")
    }
  }
}
