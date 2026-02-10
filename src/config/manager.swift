import Fcitx
import Logging
import SwiftUI

func getConfig(_ uri: String) -> [String: Any] {
  guard let data = String(Fcitx.getConfig(uri)).data(using: .utf8),
    let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
  else {
    return ["ERROR": "Failed to get config"]
  }
  return json
}

func setConfig(_ uri: String, _ option: String, _ value: Any) {
  guard
    let data = try? JSONSerialization.data(
      withJSONObject: option.isEmpty ? value : [option: value]),
    let jsonString = String(data: data, encoding: .utf8)
  else {
    FCITX_ERROR("Failed to set config")
    return
  }
  Fcitx.setConfig(uri, jsonString)
}

func extractValue(_ config: [String: Any], reset: Bool) -> Any {
  if let children = config["Children"] as? [[String: Any]] {
    var value = [String: Any]()
    for child in children {
      if let option = child["Option"] as? String {
        value[option] = extractValue(child, reset: reset)
      }
    }
    return value
  }
  if reset, let defaultValue = config["DefaultValue"] {
    return defaultValue
  }
  if !reset, let value = config["Value"] {
    return value
  }
  return ""
}

@MainActor
class ConfigManager: ObservableObject {
  @Published var uri = "" {
    didSet {
      reload()
    }
  }
  @Published var index: Int? {
    didSet {
      reload()
    }
  }
  @Published var config = [String: Any]()
  @Published var value: Any = [:]
  @Published var error: String?
  @Published var undoStack = [Any]()
  @Published var redoStack = [Any]()

  private func save(_ value: Any) {
    self.value = value
    if index == nil {
      setConfig(uri, "", value)
    } else {
      setConfig(uri, config["Option"] as? String ?? "", value)
    }
  }

  func set(_ value: Any) {
    undoStack.append(self.value)
    redoStack.removeAll()
    save(value)
  }

  func undo() {
    guard let lastState = undoStack.popLast() else {
      return
    }
    redoStack.append(self.value)
    save(lastState)
  }

  func redo() {
    guard let nextState = redoStack.popLast() else {
      return
    }
    undoStack.append(self.value)
    save(nextState)
  }

  func reset() {
    set(extractValue(self.config, reset: true))
  }

  private func reload() {
    undoStack.removeAll()
    redoStack.removeAll()
    if uri.isEmpty {
      return
    }
    let config: [String: Any] = getConfig(uri)
    if let error = config["ERROR"] as? String {
      self.config = [:]
      self.value = [:]
      self.error = error
    } else {
      if let index = index, let children = config["Children"] as? [[String: Any]],
        index >= 0 && index < children.count
      {
        self.config = children[index]
      } else {
        self.config = config
      }
      self.value = extractValue(self.config, reset: false)
      self.error = nil
    }
  }
}
