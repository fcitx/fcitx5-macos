import SwiftUI

struct ExternalView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  @State private var showExportCurrentTheme = false
  @State private var showCustomPhrase = false
  @State private var showDictManager = false
  @State private var showQuickPhrase = false
  @State private var showDialog = false
  @State private var showAlert = false
  @ObservedObject private var manager = ConfigManager()

  var body: some View {
    let option = data["Option"] as? String
    let external = data["External"] as? String
    switch option {
    case "ExportCurrentTheme":
      Button {
        showExportCurrentTheme = true
      } label: {
        Image(systemName: "square.and.arrow.up")
      }
      .sheet(isPresented: $showExportCurrentTheme) {
        ExportThemeView()
      }
    case "UserFontDir":
      Button {
        let fontDir = homeDir.appendingPathComponent("Library/Fonts")
        NSWorkspace.shared.open(fontDir)
      } label: {
        Image(systemName: "folder")
      }
    case "SystemFontDir":
      Button {
        let fontDir = URL(fileURLWithPath: "/Library/Fonts")
        NSWorkspace.shared.open(fontDir)
      } label: {
        Image(systemName: "folder")
      }
    case "UserDataDir":
      Button {
        mkdirP(rimeLocalDir.localPath())
        NSWorkspace.shared.open(rimeLocalDir)
      } label: {
        Image(systemName: "folder")
      }
    case "PluginDir":
      Button {
        mkdirP(jsPluginDir.localPath())
        NSWorkspace.shared.open(jsPluginDir)
      } label: {
        Image(systemName: "folder")
      }
    case "CustomPhrase":
      Button {
        showCustomPhrase = true
      } label: {
        Image(systemName: "gear")
      }
      .sheet(isPresented: $showCustomPhrase) {
        CustomPhraseView().refreshItems()
      }
    case "DictManager":
      Button {
        showDictManager = true
      } label: {
        Image(systemName: "gear")
      }
      .sheet(isPresented: $showDictManager) {
        DictManagerView().refreshDicts()
      }
    default:
      switch external {
      // Its Option is different in Pinyin and QuickPhrase, so use External as source of truth.
      case "fcitx://config/addon/quickphrase/editor":
        Button {
          showQuickPhrase = true
        } label: {
          Image(systemName: "gear")
        }
        .sheet(isPresented: $showQuickPhrase) {
          QuickPhraseView().refreshFiles()
        }
      default:
        Button {
          if let external = external, external.starts(with: "fcitx://config/") {
            manager.uri = external
            showDialog = true
          } else {
            showAlert = true
          }
        } label: {
          Image(systemName: "gear")
        }
        .sheet(isPresented: $showDialog) {
          VStack {
            ScrollView([.vertical]) {  // ScrollView is useful for punctuation map.
              BasicConfigView(
                config: manager.config, value: manager.value, onUpdate: { manager.set($0) }
              ).padding()
            }
            FooterView(
              manager: manager,
              onClose: {
                showDialog = false
              })
          }
        }
        .alert(
          Text("Error"),
          isPresented: $showAlert,
          presenting: ()
        ) { _ in
          Button {
            showAlert = false
          } label: {
            Text("OK")
          }
        } message: { _ in
          Text("Unsupported config")
        }
      }
    }
  }
}
