import SwiftUI

private struct ListItem: Identifiable {
  let id = UUID()
  var value: Any
}

private func deserialize(_ value: Any) -> [ListItem] {
  guard let value = value as? [String: Any] else {
    return []
  }
  return (0..<value.count).compactMap { i in ListItem(value: value[String(i)] ?? "") }
}

private func serialize(_ value: [ListItem]) -> [String: Any] {
  return value.enumerated().reduce(into: [String: Any]()) { result, pair in
    result[String(pair.offset)] = pair.element.value
  }
}

struct ListView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any
  @State private var list: [ListItem]

  init(data: [String: Any], value: Binding<Any>) {
    self.data = data
    self._value = value
    self._list = State(initialValue: deserialize(value.wrappedValue))
  }

  private func moveUp(index: Int) {
    guard index > 0 else { return }
    list.swapAt(index, index - 1)
    value = serialize(list)
  }

  private func remove(at index: Int) {
    list.remove(at: index)
    value = serialize(list)
  }

  private func add(at index: Int) {
    list.insert(ListItem(value: ""), at: index)
    value = serialize(list)
  }

  var body: some View {
    let type = data["Type"] as? String ?? ""
    let childType = String(type.suffix(type.count - "List|".count))
    let childData = mergeChild(data, "Type", childType)
    VStack {
      if childType.starts(with: "Entries") {
        HStack {
          ForEach(Array((data["Children"] as? [[String: String]] ?? []).enumerated()), id: \.0) {
            _, child in
            Text(child["Description"] ?? "").frame(maxWidth: .infinity)
          }
          // Take up spaces for buttons, so that Text aligns with TextField.
          VStack {}.square()
          VStack {}.square()
          VStack {}.square()
        }
      }
      ForEach(Array(list.enumerated()), id: \.1.id) { i, item in
        HStack {
          Spacer()
          optionView(
            data: childData,
            value: Binding(
              get: { item.value },
              set: {
                list[i].value = $0
                value = serialize(list)
              })
          )
          Button {
            moveUp(index: i)
          } label: {
            Image(systemName: "arrow.up").square()
          }
          .disabled(i == 0)
          .buttonStyle(BorderlessButtonStyle())

          Button {
            remove(at: i)
          } label: {
            Image(systemName: "minus").square()
          }
          .buttonStyle(BorderlessButtonStyle())

          Button {
            add(at: i)
          } label: {
            Image(systemName: "plus").square()
          }
          .buttonStyle(BorderlessButtonStyle())
        }
      }

      Button {
        add(at: list.count)
      } label: {
        Image(systemName: "plus").square()
      }
      .buttonStyle(BorderlessButtonStyle())
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
    // Most cases.
    .onChange(of: value as? [String: String]) { newValue in
      list = deserialize(newValue ?? [:])
    }
    // Punctuation map.
    .onChange(of: value as? [String: [String: String]]) { newValue in
      list = deserialize(newValue ?? [:])
    }
  }
}
