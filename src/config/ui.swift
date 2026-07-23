import SwiftUI
import UniformTypeIdentifiers

let sectionHeaderSize: CGFloat = 16
let gapSize: CGFloat = 10
let listBorderRadius: CGFloat = 4
let listBorderColor = Color.gray.opacity(0.3)
let checkboxColumnWidth: CGFloat = 20
let minKeywordColumnWidth: CGFloat = 80
let minPhraseColumnWidth: CGFloat = 160
let configWindowWidth: CGFloat = 800
let configWindowHeight: CGFloat = 600

let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]

extension View {
  func tooltip(_ text: String) -> some View {
    HStack {
      self
      Image(systemName: "questionmark.circle.fill")
    }.help(text)
  }

  // Enlarge clickable area for border-less icon button, especially minus.
  func square() -> some View {
    self.frame(width: 20, height: 20).background(Color.black.opacity(0.001))
  }
}

func urlButton(_ text: String, _ link: String) -> some View {
  Link(text, destination: URL(string: link)!)
}

@MainActor
func selectApplication(onFinish: @escaping (String) -> Void) {
  let _ = selectFile(
    allowsMultipleSelection: false,
    canChooseDirectories: false,
    canChooseFiles: true,
    allowedContentTypes: [.application],
    directoryURL: URL(fileURLWithPath: "/Applications")
  ) { urls, _ in
    if let url = urls.first {
      onFinish(url.localPath())
    }
  }
}

func appIconFromPath(_ path: String) -> Image {
  let icon = NSWorkspace.shared.icon(forFile: path)
  return Image(nsImage: icon)
}

func getTextWidth(_ text: String, _ fontSize: CGFloat) -> CGFloat {
  return (text as NSString).size(withAttributes: [
    .font: NSFont.systemFont(ofSize: fontSize)
  ]).width
}
