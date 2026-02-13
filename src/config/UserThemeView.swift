import SwiftUI
import UniformTypeIdentifiers

private let themeDir = localDir.appendingPathComponent("theme")

struct UserThemeView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let themeName = value as? String ?? ""
    SelectFileButton(
      directory: themeDir,
      allowedContentTypes: [UTType.init(filenameExtension: "conf")!],
      onFinish: { fileName in
        value = String(fileName.dropLast(5))
      },
      label: {
        if themeName.isEmpty {
          Text("Select/Import theme")
        } else {
          Text(themeName)
        }
      },
      model: Binding(
        get: { value as? String ?? "" },
        set: { value = $0 }
      )
    )
  }
}
