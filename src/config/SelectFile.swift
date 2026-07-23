import Logging
import SwiftUI
import UniformTypeIdentifiers

private struct DuplicateFile: Identifiable {
  let id = UUID()
  let url: URL
  var fileName: String { url.lastPathComponent }
}

private func filterSelectedFiles(_ urls: [URL], allowedSuffixes: [String]?) -> [URL] {
  guard let allowedSuffixes else {
    return urls
  }
  return urls.filter { url in
    allowedSuffixes.contains { url.lastPathComponent.hasSuffix($0) }
  }
}

private func importFile(
  _ file: URL,
  to directory: URL,
  onDuplicate: @escaping (DuplicateFile) -> Void,
  onFinish: @escaping (String) -> Void
) {
  mkdirP(directory.localPath())
  var fileName = file.lastPathComponent
  if !directory.contains(file) {
    let dst = directory.appendingPathComponent(fileName)
    if dst.exists() {
      onDuplicate(DuplicateFile(url: file))
      return
    }
    if !copyFile(file, dst) {
      return
    }
  } else {
    // Need to consider subdirectory of target directory.
    let directoryPath = directory.localPath()
    fileName = String(
      file.localPath().dropFirst(
        directoryPath.hasSuffix("/") ? directoryPath.count : directoryPath.count + 1))
  }
  onFinish(fileName)
}

private func replaceImportedFile(
  _ file: DuplicateFile,
  in directory: URL,
  onFinish: @escaping (String) -> Void
) {
  let dst = directory.appendingPathComponent(file.fileName)
  _ = removeFile(dst)
  if copyFile(file.url, dst) {
    onFinish(file.fileName)
  }
}

struct DragDropFileSelector<Content>: View where Content: View {
  let allowsMultipleSelection: Bool
  let canChooseDirectories: Bool
  let canChooseFiles: Bool
  let allowedContentTypes: [UTType]
  let directoryURL: URL?
  let allowedSuffixes: [String]?
  let onSelect: ([URL]) -> Void
  let content: (_ isTargeted: Bool) -> Content

  @State private var isTargeted = false

  init(
    allowsMultipleSelection: Bool,
    canChooseDirectories: Bool = false,
    canChooseFiles: Bool = true,
    allowedContentTypes: [UTType],
    directoryURL: URL? = nil,
    allowedSuffixes: [String]? = nil,
    onSelect: @escaping ([URL]) -> Void,
    @ViewBuilder content: @escaping (_ isTargeted: Bool) -> Content
  ) {
    self.allowsMultipleSelection = allowsMultipleSelection
    self.canChooseDirectories = canChooseDirectories
    self.canChooseFiles = canChooseFiles
    self.allowedContentTypes = allowedContentTypes
    self.directoryURL = directoryURL
    self.allowedSuffixes = allowedSuffixes
    self.onSelect = onSelect
    self.content = content
  }

  private func handleSelection(_ urls: [URL]) {
    let filtered = filterSelectedFiles(urls, allowedSuffixes: allowedSuffixes)
    guard !filtered.isEmpty else {
      return
    }
    onSelect(allowsMultipleSelection ? filtered : [filtered[0]])
  }

  var body: some View {
    content(isTargeted)
      .contentShape(Rectangle())
      .onTapGesture {
        if let directoryURL {
          mkdirP(directoryURL.localPath())
        }
        let _ = selectFile(
          allowsMultipleSelection: allowsMultipleSelection,
          canChooseDirectories: canChooseDirectories,
          canChooseFiles: canChooseFiles,
          allowedContentTypes: allowedContentTypes,
          directoryURL: directoryURL
        ) { urls, _ in
          handleSelection(urls)
        }
      }
      .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
        Task { @MainActor in
          var urls = [URL]()
          for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            let url: URL? = await withCheckedContinuation { continuation in
              _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
              }
            }
            if let url {
              urls.append(url)
            }
          }
          handleSelection(urls)
        }
        return true
      }
  }
}

private struct SelectFileSheet<DropContent>: View where DropContent: View {
  let directory: URL
  let allowedContentTypes: [UTType]
  let allowedSuffixes: [String]?
  let onImport: (String) -> Void
  @Binding var showPicker: Bool
  let dropContent: () -> DropContent
  @State private var duplicateFile: DuplicateFile? = nil

  var body: some View {
    VStack(spacing: gapSize) {
      DragDropFileSelector(
        allowsMultipleSelection: false,
        allowedContentTypes: allowedContentTypes,
        directoryURL: directory,
        allowedSuffixes: allowedSuffixes,
        onSelect: { urls in
          guard let file = urls.first else { return }
          importFile(file, to: directory, onDuplicate: { duplicateFile = $0 }) { fileName in
            onImport(fileName)
            showPicker = false
          }
        }
      ) { isTargeted in
        ZStack {
          RoundedRectangle(cornerRadius: 12)
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
            .foregroundColor(isTargeted ? .accentColor : .secondary.opacity(0.5))
          VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.down").font(.system(size: 24))
            dropContent()
          }
        }
      }
      .frame(height: 160)

      Button {
        showPicker = false
      } label: {
        Text("Cancel")
      }
    }.padding()
      .alert(item: $duplicateFile) { item in
        Alert(
          title: Text("\(item.fileName) already exists. Replace?"),
          primaryButton: .default(Text("OK")) {
            replaceImportedFile(item, in: directory) { fileName in
              onImport(fileName)
              showPicker = false
            }
          },
          secondaryButton: .cancel()
        )
      }
  }
}

struct SelectFileButton<Label, DropContent>: View where Label: View, DropContent: View {
  let directory: URL
  let allowedContentTypes: [UTType]
  let allowedSuffixes: [String]?
  let hasFile: Bool
  let label: () -> Label
  let onImport: (String) -> Void
  let onClear: (() -> Void)?
  let accessibilityId: String
  let dropContent: () -> DropContent

  @State private var showPicker = false

  init(
    directory: URL,
    allowedContentTypes: [UTType]? = nil,
    allowedSuffixes: [String]? = nil,
    hasFile: Bool,
    @ViewBuilder label: @escaping () -> Label,
    onImport: @escaping (String) -> Void,
    onClear: (() -> Void)? = nil,
    accessibilityId: String = "",
    @ViewBuilder dropContent: @escaping () -> DropContent
  ) {
    self.directory = directory
    self.allowedContentTypes = allowedContentTypes ?? (allowedSuffixes.map { fileTypes($0) } ?? [])
    self.allowedSuffixes = allowedSuffixes
    self.hasFile = hasFile
    self.label = label
    self.onImport = onImport
    self.onClear = onClear
    self.accessibilityId = accessibilityId
    self.dropContent = dropContent
  }

  var body: some View {
    HStack {
      Button {
        showPicker = true
      } label: {
        label()
      }
      .sheet(isPresented: $showPicker) {
        SelectFileSheet(
          directory: directory,
          allowedContentTypes: allowedContentTypes,
          allowedSuffixes: allowedSuffixes,
          onImport: onImport,
          showPicker: $showPicker,
          dropContent: dropContent
        )
      }
      .accessibilityIdentifier(accessibilityId)

      if hasFile, let onClear {
        Button {
          onClear()
        } label: {
          Image(systemName: "xmark.circle.fill")
        }.buttonStyle(BorderlessButtonStyle())
          .accessibilityIdentifier("ClearSelectedFile")
      }
    }
  }
}
