import Fcitx
import SwiftUI

// Should only list Apps that are not available in App selector.
private let presetApps: [String] = [
  "/System/Library/CoreServices/Spotlight.app",
  "/System/Library/Input Methods/CharacterPalette.app",  // emoji picker
]

private struct AppIMConfig: Codable {
  let appId: String
  let appPath: String
  let imName: String
}

struct AppIMView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  @State private var appPath: String
  @State private var imName: String
  private var imNameMap: [String: String]

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value

    self.imNameMap = [:]
    let inputMethods = decodeJSON(String(Fcitx.imGetCurrentGroup()), [InputMethod]())
    for inputMethod in inputMethods {
      imNameMap[inputMethod.name] = inputMethod.displayName
    }

    if let config = decodeJSON(value.wrappedValue as? String ?? "", nil as AppIMConfig?) {
      self._appPath = State(initialValue: config.appPath)
      self._imName = State(initialValue: config.imName)
    } else {
      self._appPath = State(initialValue: "")
      self._imName = State(initialValue: "")
    }
  }

  private func selections() -> [String] {
    if appPath.isEmpty || presetApps.contains(appPath) {
      return [""] + presetApps
    }
    return [""] + [appPath] + presetApps
  }

  private func update(path: String, name: String) {
    let appId = bundleIdentifier(path)
    let config = AppIMConfig(appId: appId, appPath: path, imName: name)
    if let jsonData = try? JSONEncoder().encode(config),
      let jsonStr = String(data: jsonData, encoding: .utf8)
    {
      value = jsonStr
    }
  }

  var body: some View {
    let openPanel = NSOpenPanel()  // macOS 26 crashes if put outside of body.
    HStack {
      if !appPath.isEmpty {
        appIconFromPath(appPath)
      }
      Picker("", selection: $appPath) {
        ForEach(selections(), id: \.self) { key in
          if key.isEmpty {
            Text("Select App")
          } else {
            HStack {
              if appPath != key {
                appIconFromPath(key)
              }
              Text(appNameFromPath(key)).tag(key)
            }
          }
        }
      }
      Button {
        selectApplication(
          openPanel,
          onFinish: { path in
            appPath = path
          })
      } label: {
        Image(systemName: "folder")
      }
      Picker(
        NSLocalizedString("uses", comment: "App X *uses* some input method"),
        selection: $imName
      ) {
        ForEach(Array(imNameMap.keys), id: \.self) { key in
          Text(imNameMap[key] ?? "").tag(key)
        }
      }
    }.padding(.bottom, 8)
      .onChange(of: appPath) { newPath in
        update(path: newPath, name: imName)
      }
      .onChange(of: imName) { newName in
        update(path: appPath, name: newName)
      }
  }
}
