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

struct DuplicateFile: Identifiable {
  let id = UUID()
  let url: URL
  var fileName: String { url.lastPathComponent }
}

struct SelectFileButton<Label>: View where Label: View {
  let directory: URL
  let allowedContentTypes: [UTType]
  let onFinish: (String) -> Void
  let label: () -> Label
  let model: Binding<String>

  @State private var duplicateFile: DuplicateFile? = nil

  var body: some View {
    HStack {
      Button {
        mkdirP(directory.localPath())
        let _ = selectFile(
          allowsMultipleSelection: false,
          canChooseDirectories: false,
          canChooseFiles: true,
          allowedContentTypes: allowedContentTypes,
          directoryURL: directory
        ) { urls, _ in
          guard let file = urls.first else {
            return
          }
          var fileName = file.lastPathComponent
          if !directory.contains(file) {
            let dst = directory.appendingPathComponent(fileName)
            if dst.exists() {
              duplicateFile = DuplicateFile(url: file)
              return
            }
            if !copyFile(file, dst) {
              return
            }
          } else {
            // Need to consider subdirectory of www/img.
            fileName = String(file.localPath().dropFirst(directory.localPath().count))
          }
          onFinish(fileName)
        }
      } label: {
        label()
      }.sheet(item: $duplicateFile) { item in
        VStack {
          Text("\(item.fileName) already exists. Replace?")
          HStack {
            Button {
              duplicateFile = nil
            } label: {
              Text("Cancel")
            }
            Button {
              let dst = directory.appendingPathComponent(item.fileName)
              _ = removeFile(dst)
              if copyFile(item.url, dst) {
                onFinish(item.fileName)
              }
              duplicateFile = nil
            } label: {
              Text("OK")
            }.buttonStyle(.borderedProminent)
          }
        }.padding()
      }
      if !model.wrappedValue.isEmpty {
        Button {
          model.wrappedValue = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
        }.buttonStyle(BorderlessButtonStyle())
      }
    }
  }
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
