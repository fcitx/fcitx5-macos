import SwiftUI

func mergeChild(_ value: Any, _ childKey: String, _ childValue: Any) -> [String: Any] {
  var obj = value as? [String: Any] ?? [:]
  obj[childKey] = childValue
  return obj
}

struct BasicConfigView: View {
  let config: [String: Any]
  let value: Any
  let onUpdate: (Any) -> Void

  var body: some View {
    if let children = config["Children"] as? [[String: Any]] {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(children.map { ("\(config["Option"] ?? "")/\($0["Option"] ?? "")", $0) }, id: \.0) {
          (_, child) in
          let option = child["Option"] as? String ?? ""
          let type = child["Type"] as? String ?? ""
          // TODO: group case
          // Otherwise, put the label in the left column and the
          // content in the right column.
          HStack(alignment: .firstTextBaseline, spacing: 16) {
            let label = Text(child["Description"] as? String ?? "")
              .frame(maxWidth: .infinity, alignment: .trailing)
              .help(NSLocalizedString("Right click to reset this item", comment: ""))
            if type == "External" {
              label
            } else {
              label.contextMenu {
                Button {
                  onUpdate(mergeChild(value, option, extractValue(child, reset: true)))
                } label: {
                  Text("Reset to default")
                }
              }
            }
            optionView(
              data: child,
              value: Binding(
                get: { (value as? [String: Any])?[option] as? Any ?? "" },
                set: {
                  onUpdate(mergeChild(value, option, $0))
                })
            )
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    } else {
      Text("Invalid config")
    }
  }
}
