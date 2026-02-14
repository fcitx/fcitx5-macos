import SwiftUI
import UniformTypeIdentifiers

private let cssDir = wwwDir.appendingPathComponent("css")
private let fcitxPrefix = "fcitx:///file/css/"

struct CssView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let strValue = value as? String ?? ""
    SelectFileButton(
      directory: cssDir,
      allowedContentTypes: [UTType.init(filenameExtension: "css")!],
      onFinish: { fileName in
        if !fileName.isEmpty {
          value = fcitxPrefix + fileName
        }
      },
      label: {
        if !strValue.hasPrefix(fcitxPrefix) {
          Text("Select/Import CSS")
        } else {
          Text(strValue.dropFirst(fcitxPrefix.count))
        }
      },
      model: Binding(
        get: { value as? String ?? "" },
        set: { value = $0 }
      )
    )
  }
}
