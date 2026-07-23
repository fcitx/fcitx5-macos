import Fcitx
import SwiftUI

private let themeDir = localDir.appendingPathComponent("theme")

struct UserThemeView: View {
  @State private var themeName: String = ""

  var body: some View {
    SelectFileButton(
      directory: themeDir,
      allowedSuffixes: [".conf"],
      hasFile: !themeName.isEmpty,
      label: {
        if themeName.isEmpty {
          Text("Select/Import theme")
        } else {
          Text(themeName)
        }
      },
      onImport: { fileName in
        themeName = fileName.deletingPathExtension
        Fcitx.setConfig(
          "\(webpanelUri)/usertheme", "\"\(quote(themeName))\"")
      },
      onClear: {
        themeName = ""
      },
      accessibilityId: "SelectTheme"
    ) {
      Text("Click or drag theme file (.conf) here")
    }
  }
}
