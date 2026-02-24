import Fcitx
import Logging
import SwiftUI

class InputMethodConfigController: ConfigWindowController {
  let view = InputMethodConfigView()

  convenience init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: configWindowWidth, height: configWindowHeight),
      styleMask: styleMask,
      backing: .buffered, defer: false)
    window.title = NSLocalizedString("Input Methods", comment: "")
    window.center()
    self.init(window: window)
    window.contentView = NSHostingView(rootView: view)
    window.titlebarAppearsTransparent = true
    attachToolbar(window)
  }

  override func refresh() {
    view.refresh()
  }
}

struct Group: Codable {
  var name: String
  var inputMethods: [GroupItem]
}

struct GroupItem: Identifiable, Codable {
  let name: String
  let displayName: String
  let id = UUID()

  // Silence warning: immutable property will not be decoded.
  enum CodingKeys: String, CodingKey {
    case name
    case displayName
  }
}

struct InputMethodConfigView: View {
  @ObservedObject private var viewModel = ViewModel()
  @ObservedObject private var manager = ConfigManager()
  @StateObject var addGroupDialog = InputDialog(
    title: NSLocalizedString("Add an empty group", comment: "dialog title"),
    prompt: NSLocalizedString("Group name", comment: "dialog prompt"))
  @StateObject var renameGroupDialog = InputDialog(
    title: NSLocalizedString("Rename group", comment: "dialog title"),
    prompt: NSLocalizedString("Group name", comment: "dialog prompt"))

  @State var addingInputMethod = false
  @State fileprivate var addToGroup: Group?
  @State private var mouseHoverIMID: UUID?
  @State private var selectedItem: UUID?

  init() {
    refresh()
    _selectedItem = State(initialValue: getCurrentIM())
    setUri()
  }

  func refresh() {
    viewModel.load()
  }

  func setUri() {
    if let selectedItem = selectedItem,
      let name = viewModel.uuidToIM[selectedItem]
    {
      manager.uri = "fcitx://config/inputmethod/\(name)"
    }
  }

  private func getCurrentIM() -> UUID? {
    let groupName = String(Fcitx.imGetCurrentGroupName())
    let imName = String(imGetCurrentIMName())
    // Search for imName in groupName.
    for group in viewModel.groups {
      if group.name == groupName {
        for item in group.inputMethods {
          if item.name == imName {
            return item.id
          }
        }
      }
    }
    return nil
  }

  private var maxDisplayNameWidth: CGFloat {
    min(
      getTextWidth("键盘 - 英语（美国） - 英语（Colemak）", 16),
      viewModel.groups.reduce(0) { maxWidth, group in
        max(
          maxWidth,
          group.inputMethods.reduce(0) { maxIMWidth, im in
            max(maxIMWidth, getTextWidth(im.displayName, 16))
          })
      })
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $selectedItem) {
        ForEach($viewModel.groups, id: \.name) { $group in
          Section {
            HStack {
              Text(group.name)

              Button {
                renameGroupDialog.show { input in
                  viewModel.renameGroup(group, input)
                }
              } label: {
                Image(systemName: "pencil")
              }
              .buttonStyle(BorderlessButtonStyle())
              .foregroundColor(.secondary)  // As if it's in section header.
              .help(NSLocalizedString("Rename", comment: "") + " '\(group.name)'")
            }
            // Make right-click available in the whole line.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .contextMenu {
              Button(NSLocalizedString("Remove", comment: "") + " '\(group.name)'") {
                viewModel.removeGroup(group.name)
              }
            }

            Button {
              addToGroup = group
              addingInputMethod = true
            } label: {
              Text("Add input methods")
            }

            ForEach($group.inputMethods) { $inputMethod in
              HStack {
                Text(inputMethod.displayName)
                Spacer()
                if mouseHoverIMID == inputMethod.id {
                  Button {
                    viewModel.removeItem(group.name, inputMethod.id)
                  } label: {
                    Image(systemName: "minus")
                      // When system is dark and im is not selected, hover color is black by default which is hardly visible.
                      .foregroundColor(.primary)
                      .frame(maxHeight: .infinity)
                      .contentShape(Rectangle())
                  }
                  .buttonStyle(BorderlessButtonStyle())
                  .frame(alignment: .trailing)
                }
              }
              .onHover { hovering in
                mouseHoverIMID = hovering ? inputMethod.id : nil
              }
            }
            .onMove { indices, newOffset in
              group.inputMethods.move(fromOffsets: indices, toOffset: newOffset)
              viewModel.save()
            }
          }
        }
      }
      .frame(minWidth: maxDisplayNameWidth)
      .contextMenu {
        Button(NSLocalizedString("Add group", comment: "")) {
          addGroupDialog.show { input in
            viewModel.addGroup(input)
          }
        }
        Button(NSLocalizedString("Refresh", comment: "")) {
          viewModel.load()
        }
      }
    } detail: {
      if let selectedItem = selectedItem {
        if let errorMsg = viewModel.errorMsg {
          Text("Cannot show config for \(selectedItem): \(errorMsg)")
        } else {
          ScrollView {
            BasicConfigView(
              config: manager.config, value: manager.value, onUpdate: { manager.set($0) }
            )
            .padding()
          }.padding([.top], 1)  // Cannot be 0 otherwise content overlaps with title bar.
          FooterView(
            manager: manager,
            onClose: {
              FcitxInputController.closeWindow("im")
            })
        }
      } else {
        Text("Select an input method from the side bar.")
      }
    }
    .sheet(isPresented: $addGroupDialog.presented) {
      addGroupDialog.view()
    }
    .sheet(isPresented: $renameGroupDialog.presented) {
      renameGroupDialog.view()
    }
    .sheet(isPresented: $addingInputMethod) {
      AvailableInputMethodView(
        group: $addToGroup,
        onImport: {
          viewModel.load()
        },
        onAdd: add
      )
    }.onChange(of: selectedItem) { _ in
      setUri()
    }
  }

  private func add(_ inputMethods: Set<InputMethod>) {
    if let groupName = addToGroup?.name {
      viewModel.addItems(groupName, inputMethods)
    }
  }

  private class ViewModel: ObservableObject {
    @Published var groups = [Group]()
    @Published var errorMsg: String?
    var uuidToIM = [UUID: String]()

    func load() {
      uuidToIM.removeAll()
      groups = decodeJSON(String(Fcitx.imGetGroups()), [Group]())
      for group in groups {
        for im in group.inputMethods {
          uuidToIM[im.id] = im.name
        }
      }
    }

    func save() {
      do {
        let data = try JSONEncoder().encode(groups)
        if let jsonStr = String(data: data, encoding: .utf8) {
          Fcitx.imSetGroups(jsonStr)
        } else {
          FCITX_ERROR("Couldn't save input method groups: failed to encode data as UTF-8")
        }
        load()
      } catch {
        FCITX_ERROR("Couldn't save input method groups: \(error)")
      }
    }

    func addGroup(_ name: String) {
      if name == "" || groups.contains(where: { $0.name == name }) {
        return
      }
      groups.append(Group(name: name, inputMethods: []))
      save()
    }

    func removeGroup(_ name: String) {
      if groups.count <= 1 {
        return
      }
      self.groups = self.groups.filter({ $0.name != name })
      self.save()
    }

    func renameGroup(_ group: Group, _ name: String) {
      if name == "" || groups.contains(where: { $0.name == name }) {
        return
      }
      for i in 0..<self.groups.count {
        if self.groups[i].name == group.name {
          self.groups[i].name = name
          break
        }
      }
      save()
    }

    func removeItem(_ groupName: String, _ uuid: UUID) {
      for i in 0..<self.groups.count {
        if self.groups[i].name == groupName {
          self.groups[i].inputMethods.removeAll(where: { $0.id == uuid })
          break
        }
      }
      self.save()
    }

    func addItems(_ groupName: String, _ ims: Set<InputMethod>) {
      for i in 0..<self.groups.count {
        if self.groups[i].name == groupName {
          for im in ims {
            let item = GroupItem(name: im.name, displayName: im.displayName)
            self.groups[i].inputMethods.append(item)
            self.uuidToIM[item.id] = item.name
          }
        }
      }
      self.save()
    }
  }
}

struct InputMethod: Codable, Hashable {
  let name: String
  let displayName: String
  let languageCode: String
}

/// A common modal dialog view-model + view builder for getting user
/// input.
///
/// The basic pattern is:
/// 1. define a StateObject for the dialog:
/// ```
/// @StateObject private var myDialog = InputDialog(title: "Title", prompt: "Some string")
/// ```
/// 2. Add the dialog view as a sheet to view:
/// ```
/// view.sheet(isPresented: $myDialog.presented) { myDialog.view() }
/// ```
/// 3. When you want to ask for user input, use `myDialog.show` and
/// pass in a callback to handle the user input:
/// ```
/// Button("Click me") {
///   myDialog.show() { userInput in
///     print("You input: \(userInput)")
///   }
/// }
/// ```
class InputDialog: ObservableObject {
  @Published var presented = false
  @Published var userInput = ""
  let title: String
  let prompt: String
  var continuation: ((String) -> Void)?

  init(title: String, prompt: String) {
    self.title = title
    self.prompt = prompt
  }

  func show(_ continuation: @escaping (String) -> Void) {
    self.continuation = continuation
    presented = true
  }

  @MainActor
  @ViewBuilder
  func view() -> some View {
    let myBinding = Binding(
      get: { self.userInput },
      set: { self.userInput = $0 }
    )
    VStack {
      TextField(title, text: myBinding)
      HStack {
        Button {
          self.presented = false
        } label: {
          Text("Cancel")
        }
        Button {
          if let cont = self.continuation {
            cont(self.userInput)
          }
          self.presented = false
        } label: {
          Text("OK")
        }.disabled(self.userInput.isEmpty)
          .buttonStyle(.borderedProminent)
      }
    }.padding()
      .frame(minWidth: 200)
  }
}
