import SwiftUI

struct VimModeView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let openPanel = NSOpenPanel()  // macOS 26 crashes if put outside of body.
    HStack {
      let appPath = appPathFromBundleIdentifier(value as? String ?? "")
      let appName = appNameFromPath(appPath)
      if !appPath.isEmpty {
        appIconFromPath(appPath)
      }
      Spacer()
      if !appName.isEmpty {
        Text(appName)
      } else if (value as? String ?? "").isEmpty {
        Text("Select App")
      } else {
        Text(value as? String ?? "")
      }
      Button {
        selectApplication(
          openPanel,
          onFinish: { path in
            value = bundleIdentifier(path)
          })
      } label: {
        Image(systemName: "folder")
      }
    }
  }
}
