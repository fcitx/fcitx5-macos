import SwiftUI

struct StringView: View, OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any
  @State private var text: String
  @State private var committed: String
  @State private var dirty = false
  @FocusState private var isFocused: Bool

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    let initial = value.wrappedValue as? String ?? ""
    self._text = State(initialValue: initial)
    self._committed = State(initialValue: initial)
  }

  private func submit() {
    if ($value.wrappedValue as? String) != text {
      $value.wrappedValue = text
    }
    committed = text
    dirty = false
  }

  var body: some View {
    // Don't update real-time. It changes parent state so the whole view is re-rendered,
    // which is buggy in punctuation map.
    TextField("", text: $text)
      .focused($isFocused)
      .lineLimit(1)
      .accessibilityIdentifier(data["Option"] as? String ?? "")
      .overlay(alignment: .trailing) {
        if isFocused && dirty {
          Button {
            isFocused = false
          } label: {
            Image(systemName: "checkmark")
              .foregroundColor(.accentColor)
          }
          .frame(width: 16, height: 16)
          .clipShape(Circle())
          .padding(.trailing, 4)
        }
      }
      .onChange(of: text) {
        if isFocused, $0 != committed {
          dirty = true
        }
      }
      .onSubmit { submit() }  // Press Enter.
      .onChange(of: isFocused) { focused in
        if !focused {  // Press Tab or click another TextField.
          submit()
        }
      }
      .onChange(of: value as? String) {
        // Because text is internal state, need to override it on reset.
        text = $0 ?? ""
        committed = text
        dirty = false
      }
  }
}
