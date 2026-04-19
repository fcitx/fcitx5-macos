// NSOpenPanel is not designed to be opened simultaneously.
import Cocoa
import UniformTypeIdentifiers

@MainActor
private var openPanel: NSOpenPanel? = nil

@MainActor
func selectFile(
  allowsMultipleSelection: Bool,
  canChooseDirectories: Bool,
  canChooseFiles: Bool,
  allowedContentTypes: [UTType],
  directoryURL: URL?,
  onSelect: @escaping ([URL], URL?) -> Void
) -> Bool {
  if openPanel != nil {
    return false
  }
  let panel = NSOpenPanel()
  openPanel = panel
  panel.allowsMultipleSelection = allowsMultipleSelection
  panel.canChooseDirectories = canChooseDirectories
  panel.canChooseFiles = canChooseFiles
  panel.allowedContentTypes = allowedContentTypes
  panel.directoryURL = directoryURL
  panel.begin { response in
    if response == .OK {
      onSelect(panel.urls, panel.directoryURL)
    }
    openPanel = nil
  }
  return true
}
