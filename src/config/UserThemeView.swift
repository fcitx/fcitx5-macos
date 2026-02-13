import SwiftUI
import UniformTypeIdentifiers

private let themeDir = localDir.appendingPathComponent("theme")

struct UserThemeView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  @State private var themeName: String

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    self._themeName = State(initialValue: value.wrappedValue as? String ?? "")
  }

  var body: some View {
    SelectFileButton(
      directory: themeDir,
      allowedContentTypes: [UTType.init(filenameExtension: "conf")!],
      onFinish: { fileName in
        themeName = String(fileName.dropLast(5))
        // Don't set value so that it doesn't affect undoStack.
        setConfig(webpanelUri, "Basic", ["UserTheme": themeName])
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
