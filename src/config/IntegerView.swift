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

  private var isFontWeight: Bool {
    data["FontWeight"] as? String == "True"
  }

  private func incrementValue(_ value: Int, maxValue: Int?) -> Int {
    let next = isFontWeight ? ((value / 100) + 1) * 100 : value + 1
    return min(next, maxValue ?? next)
  }

  private func decrementValue(_ value: Int, minValue: Int?) -> Int {
    let previous = isFontWeight ? ((value - 1) / 100) * 100 : value - 1
    return max(previous, minValue ?? previous)
  }

  private func canIncrement(maxValue: Int?) -> Bool {
    guard let maxValue = maxValue else {
      return true
    }
    return number < maxValue
  }

  private func canDecrement(minValue: Int?) -> Bool {
    guard let minValue = minValue else {
      return true
    }
    return number > minValue
  }

  var body: some View {
    let minValue = Int(data["IntMin"] as? String ?? "")
    let maxValue = Int(data["IntMax"] as? String ?? "")
    let option = data["Option"] as? String ?? ""
    HStack {
      TextField("", value: $number, formatter: numberFormatter)
        .focused($isFocused)
        .accessibilityIdentifier(option)
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
        let stepperId = option + "_stepper"
        if isFontWeight {
          Stepper {
          } onIncrement: {
            number = incrementValue(number, maxValue: maxValue)
          } onDecrement: {
            number = decrementValue(number, minValue: minValue)
          }
          .accessibilityIdentifier(stepperId)
          .disabled(!canIncrement(maxValue: maxValue) && !canDecrement(minValue: minValue))
        } else if let minValue = minValue, let maxValue = maxValue {
          Stepper(
            value: $number,
            in: minValue...maxValue,
            step: 1
          ) {}
          .accessibilityIdentifier(stepperId)
        } else {
          Stepper {
          } onIncrement: {
            number = incrementValue(number, maxValue: maxValue)
          } onDecrement: {
            number = decrementValue(number, minValue: minValue)
          }
          .accessibilityIdentifier(stepperId)
        }
      } else {
        // Stepper is too narrow.
        HStack(spacing: 0) {
          Button {
            number = decrementValue(number, minValue: minValue)
          } label: {
            Image(systemName: "minus")
          }.disabled(!canDecrement(minValue: minValue))
          Button {
            number = incrementValue(number, maxValue: maxValue)
          } label: {
            Image(systemName: "plus")
          }.disabled(!canIncrement(maxValue: maxValue))
        }
      }
    }
  }
}
