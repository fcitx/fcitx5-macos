import SwiftUI

protocol OptionViewProtocol: View {
  init(data: [String: Any], value: Binding<Any>)
}

func toOptionViewType(_ data: [String: Any])
  -> any OptionViewProtocol.Type
{
  let type = data["Type"] as? String
  switch type {
  case "Boolean":
    return BooleanView.self
  case "Color":
    return ColorView.self
  case "Enum":
    return EnumView.self
  case "Integer":
    return IntegerView.self
  case "Key":
    return KeyView.self
  case "String":
    //   if data["IsEnum"] as? String == "True" {
    //     return EnumView.self
    //   }
    return StringView.self
  // case "External":
  //   return ExternalView.self
  default:
    if let type = type {
      if type.starts(with: "List|") {
        return ListView.self
      }
    }
    // if type.starts(with: "Entries") {
    //   return EntryView.self
    // }
    // if data["Children"] != nil {
    //   // Expand: global config, link: fuzzy pinyin.
    //   return expandGroup ? GroupView.self : GroupLinkView.self
    // }
    return UnknownView.self
  }
}

@MainActor
func optionView(data: [String: Any], value: Binding<Any>) -> AnyView {
  let viewType = toOptionViewType(data)
  return AnyView(viewType.init(data: data, value: value))
}
