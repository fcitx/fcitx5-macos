import Logging
import SwiftUI

struct JsPluginView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  private var availablePlugins: [String] {
    var plugins = [String]()
    for fileName in getFileNamesWithExtension(jsPluginDir.localPath()) {
      let url = jsPluginDir.appendingPathComponent(fileName)
      if !url.isDirectory {
        continue
      }
      let packageJsonURL = url.appendingPathComponent("package.json")
      if let json = readJSON(packageJsonURL) {
        if json["license"].stringValue.hasPrefix("GPL-3.0") {
          plugins.append(fileName)
        } else {
          FCITX_WARN("Rejecting plugin \(fileName) which is not GPLv3")
        }
      } else {
        FCITX_WARN("Invalid package.json for plugin \(fileName)")
      }
    }
    return plugins
  }

  var body: some View {
    Picker(
      "",
      selection: Binding(
        get: { value as? String ?? "" },
        set: {
          if $0 != value as? String {  // Avoid unnecessary setConfig if select the same.
            value = $0
          }
        }
      )
    ) {
      ForEach(availablePlugins, id: \.self) { plugin in
        Text(plugin)
      }
    }
  }
}
