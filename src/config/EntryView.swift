import SwiftUI

struct EntryView: OptionViewProtocol {
  let data: [String: Any]
  @Binding var value: Any

  private func getChild(_ children: [[String: Any]], _ i: Int) -> [String: Any] {
    var child = children[i]
    child["Value"] = (value as? [String: Any])?[child["Option"] as? String ?? ""]
    return child
  }

  var body: some View {
    let children = data["Children"] as? [[String: Any]] ?? []
    HStack {
      ForEach(children.indices, id: \.self) { i in
        let child = getChild(children, i)
        optionView(
          data: child,
          value: Binding(
            get: { (value as? [String: Any])?[child["Option"] as? String ?? ""] as? Any ?? "" },
            set: {
              value = mergeChild(value, child["Option"] as? String ?? "", $0)
            }
          )
        )
      }
    }
  }
}
