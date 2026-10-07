import Keycode
import SwiftUI

private func recordedKeyView(_ pair: (String, String?)) -> some View {
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
  @State private var showKeyPositionHelp = false
  @State private var matchKeyPosition = false
  @State private var recordedShortcut: (String, String?) = ("", nil)
  @State private var recordedPositionShortcut: (String, String?) = ("", nil)
  @State private var recordedFcitxKey = ""
  @State private var recordedFcitxCode = ""

  var body: some View {
    let optionId = data["Option"] as? String ?? ""
    let shortcut = value as? String ?? ""
    let usesKeyPosition = fcitxStringIsKeycode(shortcut)
    return Button {
      recordedShortcut = ("", nil)
      recordedPositionShortcut = ("", nil)
      recordedFcitxKey = ""
      recordedFcitxCode = ""
      matchKeyPosition = usesKeyPosition
      showRecorder = true
    } label: {
      HStack(spacing: 6) {
        if usesKeyPosition {
          Image(systemName: "keyboard")
            .accessibilityLabel(Text("Match key position"))
        }
        recordedKeyView(shortcut.isEmpty ? ("●REC", nil) : fcitxStringToMacShortcut(shortcut))
      }
      .frame(minWidth: 100)
    }.sheet(isPresented: $showRecorder) {
      VStack {
        recordedKeyView(matchKeyPosition ? recordedPositionShortcut : recordedShortcut)
          .background(
            RecordingOverlay(
              recordedShortcut: $recordedShortcut,
              recordedPositionShortcut: $recordedPositionShortcut,
              recordedFcitxKey: $recordedFcitxKey, recordedFcitxCode: $recordedFcitxCode)
          )
          .frame(minWidth: 200, minHeight: 50)
          .accessibilityIdentifier("\(optionId)_key")
        HStack(spacing: 8) {
          Toggle(isOn: $matchKeyPosition) {
            Text("Match key position")
          }
          .toggleStyle(.switch)
          .accessibilityIdentifier("\(optionId)_key_position")
          HelpButton {
            showKeyPositionHelp = true
          }
          .accessibilityLabel(Text("About matching key position"))
          .sheet(isPresented: $showKeyPositionHelp) {
            VStack(spacing: 16) {
              Text(
                "Normally, shortcuts match the character produced by the current keyboard layout. When this option is enabled, the shortcut ignores the keyboard layout and matches only the key's position. For example, a shortcut recorded on the QWERTY A key continues to use that same position after switching to Dvorak."
              )
              .frame(maxWidth: 420, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
              Button {
                showKeyPositionHelp = false
              } label: {
                Text("OK")
              }.buttonStyle(.borderedProminent)
            }.padding()
          }
        }
        HStack {
          Button {
            showRecorder = false
          } label: {
            Text("Cancel")
          }.accessibilityIdentifier("\(optionId)_cancel")
          Button {
            value = matchKeyPosition ? recordedFcitxCode : recordedFcitxKey
            showRecorder = false
          } label: {
            Text("OK")
          }.buttonStyle(.borderedProminent)
            .accessibilityIdentifier("\(optionId)_ok")
            .disabled(matchKeyPosition ? recordedFcitxCode.isEmpty : recordedFcitxKey.isEmpty)
        }
      }.padding()
    }.condition(shortcut.isEmpty) {
      $0.help(Text("Click to record"))
    }.condition(usesKeyPosition) {
      $0.help(Text("Match key position"))
    }
    .accessibilityIdentifier(data["Option"] as? String ?? "")
  }
}
