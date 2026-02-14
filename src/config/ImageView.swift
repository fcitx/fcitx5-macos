import SwiftUI

private let fcitxPrefix = "fcitx:///file/img/"

private let modes = [
  NSLocalizedString("Local", comment: ""),
  "URL",
]

private let imageDir = wwwDir.appendingPathComponent("img")

struct ImageView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  @State private var mode: Int
  @State private var file: String {
    didSet {
      value = file.isEmpty ? "" : fcitxPrefix + file
    }
  }
  @State private var url: String {
    didSet {
      value = url
    }
  }

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    let strValue = value.wrappedValue as? String ?? ""
    let mode = strValue.isEmpty || strValue.starts(with: fcitxPrefix) ? 0 : 1
    self._mode = State(initialValue: mode)
    if mode == 0 {
      self._file = State(initialValue: String(strValue.dropFirst(fcitxPrefix.count)))
      self._url = State(initialValue: "")
    } else {
      self._file = State(initialValue: "")
      self._url = State(initialValue: strValue)
    }
  }

  var body: some View {
    VStack(alignment: .leading) {  // Avoid layout shift of Picker when switching modes.
      Picker("", selection: $mode) {
        ForEach(Array(modes.enumerated()), id: \.0) { idx, mode in
          Text(mode)
        }
      }
      if mode == 0 {
        SelectFileButton(
          directory: imageDir,
          allowedContentTypes: [.image],
          onFinish: { fileName in
            file = fileName
          },
          label: {
            if file.isEmpty {
              Text("Select image")
            } else {
              Text(file)
            }
          }, model: $file
        )
      } else {
        TextField(
          NSLocalizedString("https:// or data:image/png;base64,", comment: ""), text: $url)
      }
    }
  }
}
