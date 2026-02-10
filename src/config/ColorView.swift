import Combine
import SwiftUI

private func getAlpha(_ color: Color) -> Int {
  return Int(round(color.cgColor!.components![3] * 255.0))
}

struct ColorView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  @State private var rgb: Color
  @State private var alpha: Int

  @State private var cancellables = Set<AnyCancellable>()
  @State private var colorSubject = PassthroughSubject<Void, Never>()

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    self._rgb = State(initialValue: stringToColor(value.wrappedValue as? String ?? ""))
    self._alpha = State(initialValue: getAlpha(self._rgb.wrappedValue))
  }

  var body: some View {
    HStack {
      if #available(macOS 14.0, *) {
        ColorPicker("", selection: $rgb, supportsOpacity: true)
      } else {
        ColorPicker("", selection: $rgb, supportsOpacity: false)
        Text("Alpha (0-255)")
        TextField("", value: $alpha, formatter: numberFormatter)
      }
    }
    .onChange(of: rgb) { _ in
      if rgb != stringToColor(value as? String ?? "") {
        colorSubject.send()
      }
    }
    .onChange(of: alpha) { newValue in
      if newValue > 255 {
        alpha = 255
      } else if newValue < 0 {
        alpha = 0
      }
      if alpha != getAlpha(rgb) {
        colorSubject.send()
      }
    }
    .onChange(of: value as? String) { newValue in
      let c = stringToColor(newValue ?? "")
      let a = getAlpha(c)
      if c != self.rgb {
        self.rgb = c
      }
      if a != self.alpha {
        self.alpha = a
      }
    }
    .onAppear {
      colorSubject
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { _ in
          let s = colorToString(rgb)
          if #available(macOS 14.0, *) {
            value = s
          } else {
            value = String(format: "%@%02X", String(s.prefix(s.count - 2)), alpha)
          }
        }
        .store(in: &cancellables)
    }
  }
}
