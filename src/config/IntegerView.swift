import SwiftUI

let numberFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.allowsFloats = false
  formatter.usesGroupingSeparator = false
  return formatter
}()

struct IntegerView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any
  @Binding private var number: Int
  @FocusState private var isFocused: Bool

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    var oldNumber = Int(value.wrappedValue as? String ?? "")
    self._number = Binding(
      get: { Int(value.wrappedValue as? String ?? "") ?? 0 },
      set: {
        if oldNumber == $0 {  // Avoid twice updates when typing, see setConfig calls in log.
          return
        }
        oldNumber = $0
        value.wrappedValue = String($0)
      }
    )
  }

  var body: some View {
    let minValue = Int(data["IntMin"] as? String ?? "")
    let maxValue = Int(data["IntMax"] as? String ?? "")
    HStack {
      TextField("", value: $number, formatter: numberFormatter)
        .focused($isFocused)
        .onChange(of: isFocused) { focused in
          if !focused, let minValue = minValue, let maxValue = maxValue {
            if number < minValue {
              number = minValue
            } else if number > maxValue {
              number = maxValue
            }
          }
        }
      if #available(macOS 26.0, *) {
        if let minValue = minValue, let maxValue = maxValue {
          Stepper(
            value: $number,
            in: minValue...maxValue,
            step: 1
          ) {}
        } else {
          Stepper {
          } onIncrement: {
            number += 1
          } onDecrement: {
            number -= 1
          }
        }
      } else {
        // Stepper is too narrow.
        HStack(spacing: 0) {
          Button {
            number -= 1
          } label: {
            Image(systemName: "minus")
          }.disabled(minValue != nil && number <= minValue ?? 0)
          Button {
            number += 1
          } label: {
            Image(systemName: "plus")
          }.disabled(maxValue != nil && number >= maxValue ?? 0)
        }
      }
    }
  }
}
