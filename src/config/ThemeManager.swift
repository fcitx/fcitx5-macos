import Fcitx
import SwiftUI

struct ExportThemeView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var themeName = ""

  var body: some View {
    VStack {
      TextField(NSLocalizedString("Theme name", comment: ""), text: $themeName)
      HStack {
        Button {
          dismiss()
        } label: {
          Text("Cancel")
        }
        Button {
          Fcitx.setConfig(
            "\(webpanelUri)/exportcurrenttheme", "\"\(quote(themeName))\"")
          dismiss()
        } label: {
          Text("OK")
        }.disabled(themeName.isEmpty)
          .buttonStyle(.borderedProminent)
      }
    }.padding()
      .frame(minWidth: 200)
  }
}
