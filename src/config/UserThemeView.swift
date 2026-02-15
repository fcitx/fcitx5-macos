import Fcitx
import SwiftUI
import UniformTypeIdentifiers

private let themeDir = localDir.appendingPathComponent("theme")

struct UserThemeView: View {
  @State private var themeName: String = ""

  var body: some View {
    SelectFileButton(
      directory: themeDir,
      allowedContentTypes: [UTType.init(filenameExtension: "conf")!],
      onFinish: { fileName in
        themeName = String(fileName.dropLast(5))
        Fcitx.setConfig(
          "\(webpanelUri)/usertheme", "\"\(quote(themeName))\"")
      },
      label: {
        if themeName.isEmpty {
          Text("Select/Import theme")
        } else {
          Text(themeName)
        }
      },
      model: $themeName
    )
  }
}
