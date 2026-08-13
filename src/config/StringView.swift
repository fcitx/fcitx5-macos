import Fcitx
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

  private var isRegex: Bool {
    data["IsRegex"] as? String == "True"
      || (data["ListConstrain"] as? [String: Any])?["IsRegex"] as? String == "True"
  }

  private var isValid: Bool {
    !isRegex || text.isEmpty || Fcitx.isRegexValid(text)
  }

  private func submit() {
    if isValid {
      if ($value.wrappedValue as? String) != text {
        $value.wrappedValue = text
      }
      committed = text
      dirty = false
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      // Don't update real-time. It changes parent state so the whole view is re-rendered,
      // which is buggy in punctuation map.
      TextField("", text: $text)
        .focused($isFocused)
        .lineLimit(1)
        .accessibilityIdentifier(data["Option"] as? String ?? "")
        .overlay(alignment: .trailing) {
          if isFocused && isValid && dirty {
            Button {
              submit()
            } label: {
              Image(systemName: "checkmark")
                .foregroundColor(.accentColor)
            }
            .frame(width: 16, height: 16)
            .clipShape(Circle())
            .padding(.trailing, 4)
          }
        }
        .overlay(
          RoundedRectangle(cornerRadius: 4)
            .stroke(!isValid && !isFocused ? Color.red : Color.clear, lineWidth: 1)
        )
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
      if !isValid {
        Text("Invalid regular expression")
          .font(.caption)
          .foregroundColor(.red)
          .accessibilityIdentifier("InvalidRegex")
      }
    }
  }
}
