import SwiftUI

private func dataToOptions(_ data: [String: Any]) -> [(String, String)] {
  let original = data["Enum"] as? [String: String] ?? [:]
  let translations = data["EnumI18n"] as? [String: String] ?? original
  var res = [(String, String)]()
  for i in 0..<original.count {
    let key = String(i)
    if let value = original[key], let translation = translations[key] {
      res.append((value, translation))
    }
  }
  return res
}

struct EnumView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any
  let options: [(String, String)]
  @State private var showHelp = false

  private func getCount() -> Int {
    // Hack: on macOS < 26 disable Liquid Glass of Background/Blur in webpanel.
    if options.map({ $0.0 }).prefix(4) == ["None", "System", "Blur", "Liquid Glass"] {
      if osVersion.majorVersion >= 26 {
        return 4
      }
      return 3
    }
    return options.count
  }

  private func isThemeWithLiquidGlass() -> Bool {
    if options.map({ $0.0 }).prefix(3) == ["System", "Light", "Dark"]
      && osVersion.majorVersion >= 26
    {
      let blur = ProcessInfo.processInfo.environment["BLUR"]
      return blur == "1" || blur == "3"
    }
    return false
  }

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    self.options = dataToOptions(data)
  }

  var body: some View {
    if isThemeWithLiquidGlass() {
      HStack {
        Text("Follow App background (Liquid Glass)")
        Button {
          showHelp = true
        } label: {
          Text("?")
        }.frame(width: 20, height: 20)
          .clipShape(Circle())
          .sheet(isPresented: $showHelp) {
            VStack {
              Text(
                "When Liquid Glass is enabled, theme follows App background, which is the same behavior with built-in input methods.\nTo set fixed light/dark theme, please change Background → Blur to \"None\" or \"Blur\"."
              )
              Button {
                showHelp = false
              } label: {
                Text("OK")
              }.buttonStyle(.borderedProminent)
            }.padding()
          }
      }
    } else {
      Picker(
        "",
        selection: Binding(
          get: { value as? String ?? "" },
          set: {
            if $0 != value as? String {  // Avoid unnecessary setConfig if select the same.
              value = $0
            }
          }
        )
      ) {
        ForEach(0..<getCount(), id: \.self) { i in
          Text(options[i].1).tag(options[i].0)
        }
      }
    }
  }
}
