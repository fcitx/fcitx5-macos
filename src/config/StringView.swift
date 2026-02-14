import SwiftUI

struct StringView: View, OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any
  @Binding private var text: String

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    var oldText = value.wrappedValue as? String ?? ""
    self._text = Binding(
      get: { value.wrappedValue as? String ?? "" },
      set: {
        if oldText == $0 {  // Avoid twice updates when typing, see setConfig calls in log.
          return
        }
        oldText = $0
        value.wrappedValue = $0
      }
    )
  }

  var body: some View {
    TextField("", text: $text)
  }
}
