import SwiftUI

func recordedKeyView(_ pair: (String, String?)) -> some View {
  let (normalFont, smallerFont) = pair
  if let smallerFont = smallerFont {
    return Text(normalFont) + Text(smallerFont).font(.caption)
  } else {
    return Text(normalFont)
  }
}

struct KeyView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  @State private var showRecorder = false
  @State private var recordedShortcut: (String, String?) = ("", nil)
  @State private var recordedKey = ""
  @State private var recordedModifiers = NSEvent.ModifierFlags()
  @State private var recordedCode: UInt16 = 0

  var body: some View {
    let optionId = data["Option"] as? String ?? ""
    return Button {
      recordedShortcut = ("", nil)
      recordedKey = ""
      recordedModifiers = NSEvent.ModifierFlags()
      recordedCode = 0
      showRecorder = true
    } label: {
      recordedKeyView(
        value as? String == "" ? ("●REC", nil) : fcitxStringToMacShortcut(value as? String ?? "")
      )
      .frame(
        minWidth: 100)
    }.sheet(isPresented: $showRecorder) {
      VStack {
        recordedKeyView(recordedShortcut)
          .background(
            RecordingOverlay(
              recordedShortcut: $recordedShortcut, recordedKey: $recordedKey,
              recordedModifiers: $recordedModifiers, recordedCode: $recordedCode)
          )
          .frame(minWidth: 200, minHeight: 50)
          .accessibilityIdentifier("\(optionId)_key")
        HStack {
          Button {
            showRecorder = false
          } label: {
            Text("Cancel")
          }.accessibilityIdentifier("\(optionId)_cancel")
          Button {
            value = macKeyToFcitxString(recordedKey, recordedModifiers, recordedCode)
            showRecorder = false
          } label: {
            Text("OK")
          }.buttonStyle(.borderedProminent)
            .accessibilityIdentifier("\(optionId)_ok")
        }
      }.padding()
    }.help(
      value as? String == ""
        ? NSLocalizedString("Click to record", comment: "") : value as? String ?? ""
    )
    .accessibilityIdentifier(data["Option"] as? String ?? "")
  }
}
