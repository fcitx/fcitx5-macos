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
    if data["AppIM"] as? String == "True" {
      return AppIMView.self
    }
    if data["CSS"] as? String == "True" {
      return CssView.self
    }
    if data["IsEnum"] as? String == "True" {
      return EnumView.self
    }
    if data["Image"] as? String == "True" {
      return ImageView.self
    }
    if data["Font"] as? String == "True" {
      return FontView.self
    }
    if data["Plugin"] as? String == "True" {
      return JsPluginView.self
    }
    if data["UserTheme"] as? String == "True" {
      return UserThemeView.self
    }
    if data["VimMode"] as? String == "True" {
      return VimModeView.self
    }
    return StringView.self
  case "External":
    return ExternalView.self
  default:
    if let type = type {
      if type.starts(with: "List|") {
        return ListView.self
      }
      if type.starts(with: "Entries") {
        return EntryView.self
      }
    }
    if data["Children"] != nil {
      return GroupView.self
    }
    return UnknownView.self
  }
}

@MainActor
func optionView(data: [String: Any], value: Binding<Any>) -> AnyView {
  let viewType = toOptionViewType(data)
  return AnyView(viewType.init(data: data, value: value))
}
