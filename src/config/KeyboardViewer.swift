import Fcitx
import Logging
import SwiftUI

// Configurable
private let keyWidth: CGFloat = 28
private let spacing: CGFloat = 3
private let keyCornerRadius: CGFloat = 4

// Fixed
private let deleteWidth: CGFloat = keyWidth * 1.5 + spacing / 2
private let keyboardWidth: CGFloat = 13 * keyWidth + deleteWidth + 13 * spacing
private let returnWidth: CGFloat = (keyboardWidth - 11 * keyWidth - 12 * spacing) / 2
private let shiftWidth: CGFloat = (keyboardWidth - 10 * keyWidth - 11 * spacing) / 2
private let spaceWidth: CGFloat = 5 * keyWidth + 4 * spacing
private let commandWidth: CGFloat = (keyboardWidth - spaceWidth - 7 * keyWidth - 9 * spacing) / 2
private let arrowKeyHeight: CGFloat = (keyWidth - spacing / 2) / 2

private func getForeground(_ colorScheme: ColorScheme) -> Color {
  return colorScheme == .dark
    ? Color(
      .sRGB, red: 234 / 255, green: 234 / 255, blue: 234 / 255)
    : Color(
      .sRGB, red: 86 / 255, green: 110 / 255, blue: 164 / 255)
}

private func getBackground(_ colorScheme: ColorScheme, _ fixed: Bool) -> Color {
  switch (colorScheme, fixed) {
  case (.dark, false):
    Color(.sRGB, red: 120 / 255, green: 120 / 255, blue: 120 / 255)
  case (_, false):
    Color(.sRGB, red: 228 / 255, green: 233 / 255, blue: 241 / 255)
  case (.dark, true):
    Color(.sRGB, red: 93 / 255, green: 93 / 255, blue: 93 / 255)
  case (_, true):
    Color(.sRGB, red: 240 / 255, green: 243 / 255, blue: 247 / 255)
  }
}

struct KeyboardViewer: View {
  @ObservedObject private var modifierState = ModifierState.shared
  @State private var symbolsCache = [String: [[String]]]()
  @State private var symbols = [[String]]()
  @Binding var layout: String

  private func updateSymbols() {
    let shift = modifierState.shift
    let key = "\(layout)_\(shift)"
    if let cached = symbolsCache[key] {
      FCITX_DEBUG("KeyboardViewer: hit \(key) cache")
      symbols = cached
    } else {
      FCITX_DEBUG("KeyboardViewer: miss \(key) cache")
      let result = decodeJSON(
        String(Fcitx.getSymbolsOfLayout(layout, shift)), [[String]]())
      symbolsCache[key] = result
      symbols = result
    }
  }

  @Environment(\.colorScheme) var colorScheme

  private struct RoundedCorner: Shape {
    let topLeft: CGFloat
    let topRight: CGFloat
    let bottomLeft: CGFloat
    let bottomRight: CGFloat

    func path(in rect: CGRect) -> Path {
      var path = Path()
      path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
      path.addArc(
        center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight), radius: topRight,
        startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
      path.addArc(
        center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
        radius: bottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
      path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
      path.addArc(
        center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft), radius: bottomLeft,
        startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
      path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
      path.addArc(
        center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft), radius: topLeft,
        startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
      return path
    }
  }

  private struct Key: View {
    @Environment(\.colorScheme) var colorScheme

    let text: String
    let fixed: Bool
    let width: CGFloat
    let height: CGFloat
    let topRounded: Bool
    let bottomRounded: Bool

    init(
      _ text: String, fixed: Bool = true, width: CGFloat = keyWidth, height: CGFloat = keyWidth,
      topRounded: Bool = true, bottomRounded: Bool = true
    ) {
      self.text = text
      self.fixed = fixed
      self.width = width
      self.height = height
      self.topRounded = topRounded
      self.bottomRounded = bottomRounded
    }

    var body: some View {
      Text(text)
        .foregroundColor(getForeground(colorScheme))
        .frame(width: width, height: height)
        .background(getBackground(colorScheme, fixed))
        .clipShape(
          RoundedCorner(
            topLeft: topRounded ? keyCornerRadius : 0,
            topRight: topRounded ? keyCornerRadius : 0,
            bottomLeft: bottomRounded ? keyCornerRadius : 0,
            bottomRight: bottomRounded ? keyCornerRadius : 0
          ))
    }
  }

  var body: some View {
    VStack {
      if symbols.count == 4 {
        let keyboard = VStack(spacing: spacing) {
          HStack(spacing: spacing) {
            ForEach(symbols[0].indices, id: \.self) { col in
              Key(symbols[0][col], fixed: false)
            }
            Key("⌫", width: deleteWidth)
          }
          HStack(spacing: spacing) {
            Key("⇥", width: deleteWidth)
            ForEach(symbols[1].indices, id: \.self) { col in
              Key(symbols[1][col], fixed: false)
            }
          }
          HStack(spacing: spacing) {
            Key("⇪", width: returnWidth)
            ForEach(symbols[2].indices, id: \.self) { col in
              Key(symbols[2][col], fixed: false)
            }
            Key("↩", width: returnWidth)
          }
          HStack(spacing: spacing) {
            Key("⇧", width: shiftWidth)
            ForEach(symbols[3].indices, id: \.self) { col in
              Key(symbols[3][col], fixed: false)
            }
            Key("⇧", width: shiftWidth)
          }
          HStack(spacing: spacing) {
            Key("fn")
            Key("⌃")
            Key("⌥")
            Key("⌘", width: commandWidth)
            Key("", width: spaceWidth)
            Key("⌘", width: commandWidth)
            Key("⌥")
            VStack {
              Spacer()
              Key("←", height: arrowKeyHeight)
            }
            .frame(height: keyWidth)
            VStack(spacing: spacing / 2) {
              Key("↑", height: arrowKeyHeight, topRounded: true, bottomRounded: false)
              Key("↓", height: arrowKeyHeight, topRounded: false, bottomRounded: true)
            }
            VStack {
              Spacer()
              Key("→", height: arrowKeyHeight)
            }
            .frame(height: keyWidth)
          }
        }
        .padding(spacing)

        if colorScheme == .dark {
          keyboard.background(Color(.sRGB, red: 75 / 255, green: 75 / 255, blue: 75 / 255))
        } else {
          keyboard.overlay(
            RoundedRectangle(cornerRadius: keyCornerRadius)
              .stroke(Color(.sRGB, red: 199 / 255, green: 206 / 255, blue: 211 / 255), lineWidth: 1)
          )
        }
      }
    }.onAppear {
      updateSymbols()
    }
    .onChange(of: layout) { _ in
      updateSymbols()
    }
    .onChange(of: modifierState.shift) { shift in
      updateSymbols()
    }
  }
}
