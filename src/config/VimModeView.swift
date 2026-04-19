import SwiftUI

struct VimModeView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
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
          onFinish: { path in
            value = bundleIdentifier(path)
          })
      } label: {
        Image(systemName: "folder")
      }
    }
  }
}
