import SwiftUI

struct BooleanView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  var body: some View {
    Toggle(
      "",
      isOn: Binding(
        get: { value as? String == "True" },
        set: {
          value = $0 ? "True" : "False"
        })
    )
    .toggleStyle(.switch)
  }
}
