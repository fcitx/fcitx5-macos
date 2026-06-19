import Fcitx
import Logging
import SwiftUI
import UniformTypeIdentifiers

class ImportTableVM: ObservableObject {
  // Record IMs and auto add new ones.
  @Published private(set) var ims = [String]()
  @Published var selectedFiles = [URL]()
  var onError: (String) -> Void = { _ in }
  var finalize: () -> Void = {}

  func setHandler(onError: @escaping (String) -> Void, finalize: @escaping () -> Void) {
    self.onError = onError
    self.finalize = finalize
  }

  func load() {
    ims = getFileNamesWithExtension(imLocalDir.localPath(), ".conf")
  }

  func addFiles(_ urls: [URL]) {
    let allowedSuffixes = [".conf", ".conf.in", ".dict", ".txt"]
    for url in urls {
      let fileName = url.lastPathComponent
      if allowedSuffixes.contains(where: { fileName.hasSuffix($0) }) && !selectedFiles.contains(url)
      {
        selectedFiles.append(url)
      }
    }
  }

  func importFiles() -> [String] {
    mkdirP(imLocalDir.localPath())
    mkdirP(tableLocalDir.localPath())

    var importedConfs = [String]()
    for url in selectedFiles {
      let fileName = url.lastPathComponent
      if fileName.hasSuffix(".txt") {
        continue
      }

      let destDir: URL
      let destFileName: String

      if fileName.hasSuffix(".conf") || fileName.hasSuffix(".conf.in") {
        destDir = imLocalDir
        destFileName = fileName.hasSuffix(".conf.in") ? String(fileName.dropLast(3)) : fileName
      } else {
        destDir = tableLocalDir
        destFileName = fileName
      }

      let dest = destDir.appendingPathComponent(destFileName)
      if dest.exists() {
        onError("File already exists: \(destFileName)")
        continue
      }

      if copyFile(url, dest) {
        if fileName.hasSuffix(".conf") || fileName.hasSuffix(".conf.in") {
          let baseName =
            destFileName.hasSuffix(".conf")
            ? String(destFileName.dropLast(5))
            : String(destFileName.dropLast(8))
          importedConfs.append(baseName)
        }
      } else {
        onError("Failed to copy: \(fileName)")
      }
    }
    return importedConfs
  }
}

private func convertTxt(_ urls: [URL]) -> [String] {
  let converter = libraryDir.appendingPathComponent("bin/libime_tabledict").localPath()
  let txtUrls = urls.filter { $0.lastPathComponent.hasSuffix(".txt") }
  var failures = [String]()
  for url in txtUrls {
    let baseName = url.deletingPathExtension().lastPathComponent
    let dest = tableLocalDir.appendingPathComponent("\(baseName).main.dict")
    if !exec(converter, [url.localPath(), dest.localPath()]) {
      failures.append(url.lastPathComponent)
    }
  }
  return failures
}

struct ImportTableView: View {
  @Environment(\.dismiss) private var dismiss

  @StateObject private var importTableVM = ImportTableVM()
  let onAdd: ([String]) -> Void
  let onError: (String) -> Void
  let finalize: () -> Void

  init(
    onAdd: @escaping ([String]) -> Void, onError: @escaping (String) -> Void,
    finalize: @escaping () -> Void
  ) {
    self.onAdd = onAdd
    self.onError = onError
    self.finalize = finalize
  }

  // Actually in should be conf.in but that results in nil
  // Txt effectively allows all plain text extensions so we have to filter afterwards.
  private let allowedTypes = fileTypes(["conf", "in", "dict", "txt"])

  var body: some View {
    VStack(spacing: gapSize) {
      // Drag and Drop Area - Fixed Height
      ZStack {
        RoundedRectangle(cornerRadius: 12)
          .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
          .foregroundColor(.secondary.opacity(0.5))

        VStack(spacing: 8) {
          Image(systemName: "square.and.arrow.down")
            .font(.system(size: 24))
          VStack(spacing: 2) {
            Text("Click or drag to this area").accessibilityIdentifier("DragAndDrop")
            Text("Table config: *.conf or *.conf.in")
            Text("Table data: *.dict or *.txt")
          }
        }
      }
      .frame(height: 160)
      .contentShape(Rectangle())
      .onTapGesture {
        _ = selectFile(
          allowsMultipleSelection: true,
          canChooseDirectories: false,
          canChooseFiles: true,
          allowedContentTypes: allowedTypes,
          directoryURL: nil
        ) { urls, _ in
          importTableVM.addFiles(urls)
        }
      }
      .onDrop(of: [.fileURL], isTargeted: nil) { providers in
        for provider in providers {
          _ = provider.loadObject(ofClass: URL.self) { url, error in
            if let url = url {
              let fileName = url.lastPathComponent
              let allowedSuffixes = [".conf", ".conf.in", ".dict", ".txt"]
              if allowedSuffixes.contains(where: { fileName.hasSuffix($0) }) {
                DispatchQueue.main.async {
                  importTableVM.addFiles([url])
                }
              }
            }
          }
        }
        return true
      }

      // File List Area - Fixed Height to prevent shift
      VStack(alignment: .leading, spacing: 4) {
        if !importTableVM.selectedFiles.isEmpty {
          Text("Selected \(importTableVM.selectedFiles.count) file(s)")

          List {
            ForEach(importTableVM.selectedFiles.indices, id: \.self) { index in
              HStack {
                Text(importTableVM.selectedFiles[index].lastPathComponent)
                  .lineLimit(1)
                  .accessibilityIdentifier("SelectedFile_\(index)")
                Spacer()
                Button {
                  importTableVM.selectedFiles.remove(at: index)
                } label: {
                  Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
              }
            }
          }
          .background(Color.secondary.opacity(0.05))
          .cornerRadius(listBorderRadius)

        } else {
          // Placeholder to reserve space and avoid layout shift
          Text("")
          VStack {
            Spacer()
            Text("No files selected")
              .foregroundColor(.secondary)
            Spacer()
          }
          .frame(maxWidth: .infinity)
          .background(Color.secondary.opacity(0.05))
          .cornerRadius(listBorderRadius)
        }
      }
      .frame(height: 160)

      Spacer()

      HStack {
        Button {
          dismiss()
        } label: {
          Text("Cancel")
        }

        Button {
          let existingIMs = Set(importTableVM.ims)
          let failures = convertTxt(importTableVM.selectedFiles)
          let importedConfs = importTableVM.importFiles()
          importTableVM.load()
          let newIMs = importTableVM.ims.filter { im in
            !existingIMs.contains(im) && importedConfs.contains(im)
          }
          Fcitx.reload()
          onAdd(newIMs)
          dismiss()
          if !failures.isEmpty {
            let msg = String(
              format: NSLocalizedString("Failed to convert txt table(s): %@", comment: ""),
              failures.joined(separator: ", "))
            onError(msg)
          }
          importTableVM.finalize()
        } label: {
          Text("Import")
        }.buttonStyle(.borderedProminent)
          .disabled(importTableVM.selectedFiles.isEmpty)
          .accessibilityIdentifier("Import")
      }
    }
    .padding()
    .onAppear {
      mkdirP(imLocalDir.localPath())
      mkdirP(tableLocalDir.localPath())
      importTableVM.setHandler(onError: onError, finalize: finalize)
      importTableVM.load()
    }
  }
}
