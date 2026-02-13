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
          let description = child["Description"] as? String ?? ""
          let type = child["Type"] as? String ?? ""
          let label =
            type == "External"
            ? Text(description) as any View
            : Text(description).contextMenu {
              Button {
                onUpdate(mergeChild(value, option, extractValue(child, reset: true)))
              } label: {
                Text("Reset to default")
              }
            }
          let view = optionView(
            data: child,
            value: Binding(
              get: { (value as? [String: Any])?[option] as? Any ?? "" },
              set: {
                onUpdate(mergeChild(value, option, $0))
              })
          )
          if toOptionViewType(child) == GroupView.self {
            // For group, put it inside a box and let it span two columns.
            VStack(alignment: .leading, spacing: 4) {
              AnyView(label).font(.title3)
                .help(NSLocalizedString("Right click to reset this group", comment: ""))
              view
            }
          } else {
            // For non-group, put the label in the left column and the
            // content in the right column.
            HStack(alignment: .firstTextBaseline, spacing: 16) {
              // Hack: Punctuation map looks better without label.
              if type != "List|Entries$PunctuationMapEntryConfig" {
                AnyView(label).frame(maxWidth: .infinity, alignment: .trailing)
                  .help(NSLocalizedString("Right click to reset this item", comment: ""))
              }
              view.frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
    } else {
      Text("Unsupported config")
    }
  }
}
