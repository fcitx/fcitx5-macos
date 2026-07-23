import SwiftUI

private let cssDir = wwwDir.appendingPathComponent("css")
private let fcitxPrefix = "fcitx:///file/css/"

struct CssView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    let strValue = value as? String ?? ""
    SelectFileButton(
      directory: cssDir,
      allowedSuffixes: [".css"],
      hasFile: !strValue.isEmpty,
      label: {
        if !strValue.hasPrefix(fcitxPrefix) {
          Text("Select/Import CSS")
        } else {
          Text(strValue.dropFirst(fcitxPrefix.count))
        }
      },
      onImport: { fileName in
        value = fcitxPrefix + fileName
      },
      onClear: {
        value = ""
      },
      accessibilityId: "SelectCss"
    ) {
      Text("Click or drag .css file here")
    }
  }
}
