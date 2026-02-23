import AlertToast
import Fcitx
import Logging
import SwiftUI

let en = "en"
let popularIMs = ["keyboard-us", "pinyin", "shuangpin", "wbx", "rime", "mozc", "hallelujah"]

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

private struct Group: Codable {
  var name: String
  var inputMethods: [GroupItem]
}

private struct GroupItem: Identifiable, Codable {
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
  @State fileprivate var inputMethodsToAdd = Set<InputMethod>()
  @State fileprivate var addToGroup: Group?
  @State private var mouseHoverIMID: UUID?
  @State private var selectedItem: UUID?

  @State private var showImportTable = false
  @State private var importTableErrorMsg = ""
  @State private var showImportTableError = false

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
      VStack {
        AvailableInputMethodView(
          selection: $inputMethodsToAdd,
          addToGroup: $addToGroup,
          onDoubleClick: add
        ).padding([.leading])
        HStack {
          Button {
            addingInputMethod = false
            inputMethodsToAdd = Set()
          } label: {
            Text("Cancel")
          }

          Spacer()

          Button {
            showImportTable = true
          } label: {
            Text("Import customized table")
          }
          Button {
            add()
            addingInputMethod = false
          } label: {
            Text("Add")
          }.buttonStyle(.borderedProminent)
            .disabled(inputMethodsToAdd.isEmpty)
        }.padding()
      }.padding([.top])
        .sheet(isPresented: $showImportTable) {
          ImportTableView().load(
            onError: { msg in
              importTableErrorMsg = msg
              showImportTableError = true
            },
            finalize: {
              viewModel.load()
            })
        }
        .toast(isPresenting: $showImportTableError) {
          AlertToast(
            displayMode: .hud,
            type: .error(Color.red), title: importTableErrorMsg)
        }
    }.onChange(of: selectedItem) { _ in
      setUri()
    }
  }

  private func add() {
    if let groupName = addToGroup?.name {
      viewModel.addItems(groupName, inputMethodsToAdd)
    }
    inputMethodsToAdd = Set()
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

private func normalizeLanguageCode(_ code: String) -> String {
  // "".split throws
  if code.isEmpty {
    return ""
  }
  return String(code.split(separator: "_")[0])
}

// Match English, system language (or language assigned to Fcitx5) and languages of enabled input methods.
private func languageCodeMatch(_ code: String, _ languagesOfEnabledIMs: Set<String>) -> Bool {
  guard let languageCode = Locale.current.language.languageCode?.identifier else {
    return true
  }
  if code == en {
    return true
  }
  let normalized = normalizeLanguageCode(code)
  return normalized == languageCode || languagesOfEnabledIMs.contains(normalized)
}

struct AvailableInputMethodView: View {
  @Binding fileprivate var selection: Set<InputMethod>
  @Binding fileprivate var addToGroup: Group?
  @StateObject private var viewModel = ViewModel()
  @State var enabledIMs = Set<String>()
  var onDoubleClick: () -> Void

  var body: some View {
    NavigationSplitView {
      List(selection: $viewModel.selectedLanguageCode) {
        ForEach(viewModel.languages(), id: \.code) { language in
          Text(language.localized)
        }
      }
      Toggle(
        NSLocalizedString("Only show current language", comment: ""),
        isOn: Binding(
          get: { viewModel.addIMOnlyShowCurrentLanguage ?? false },
          set: { viewModel.addIMOnlyShowCurrentLanguage = $0 }
        )
      )
    } detail: {
      // Input methods for this language
      if viewModel.selectedLanguageCode != nil {
        List(selection: $selection) {
          ForEach(viewModel.availableIMsForLanguage, id: \.self) { im in
            Text(im.displayName).fontWeight(popularIMs.contains(im.name) ? .bold : .regular)
          }
        }.contextMenu(forSelectionType: InputMethod.self) { items in
        } primaryAction: { items in
          onDoubleClick()
          // Hack: enabledIMs isn't synced with group's inputMethods.
          enabledIMs.formUnion(items.map { $0.name })
          viewModel.refresh(enabledIMs)
        }
      } else {
        Text("Select a language from the left list.")
      }
    }
    .frame(minWidth: 640, minHeight: 480)
    .onAppear {
      enabledIMs = Set(addToGroup?.inputMethods.map { $0.name } ?? [])
      viewModel.refresh(enabledIMs)
    }
    .alert(
      NSLocalizedString("Error", comment: ""),
      isPresented: $viewModel.hasError,
      presenting: ()
    ) { _ in
      Button {
        viewModel.errorMsg = nil
      } label: {
        Text("OK")
      }.buttonStyle(.borderedProminent)
    } message: { _ in
      Text(viewModel.errorMsg!)
    }
  }

  private class ViewModel: ObservableObject {
    @AppStorage("AddIMOnlyShowCurrentLanguage") var addIMOnlyShowCurrentLanguage: Bool?
    @Published var availableIMs = [String: [InputMethod]]()
    @Published var hasError = false
    @Published var selectedLanguageCode: String? {
      didSet {
        updateList()
      }
    }
    @Published var alreadyEnabled = Set<String>() {
      didSet {
        updateList()
      }
    }
    @Published var availableIMsForLanguage = [InputMethod]()
    var languagesOfEnabledIMs = Set<String>()

    var errorMsg: String? {
      didSet {
        hasError = (errorMsg != nil)
      }
    }

    private func updateList() {
      guard let selectedLanguageCode = selectedLanguageCode,
        let ims = availableIMs[selectedLanguageCode]
      else {
        availableIMsForLanguage = []
        return
      }
      availableIMsForLanguage = ims.filter { !alreadyEnabled.contains($0.name) }.sorted {
        a, b in
        // Pin popular input methods.
        let ia = popularIMs.firstIndex(of: a.name)
        let ib = popularIMs.firstIndex(of: b.name)
        if ia == nil && ib != nil {
          return false
        }
        if ia != nil && ib == nil {
          return true
        }
        if let ia = ia, let ib = ib {
          return ia < ib
        }
        return a.displayName.localizedCompare(b.displayName) == .orderedAscending
      }
    }

    func refresh(_ alreadyEnabled: Set<String>) {
      availableIMs.removeAll()
      languagesOfEnabledIMs.removeAll()
      let array = decodeJSON(String(Fcitx.imGetAvailableIMs()), [InputMethod]())
      for im in array {
        let code = im.languageCode.isEmpty ? "und" : im.languageCode
        availableIMs[code, default: []].append(im)
        if alreadyEnabled.contains(im.name) {
          languagesOfEnabledIMs.update(with: normalizeLanguageCode(code))
        }
      }
      self.alreadyEnabled = alreadyEnabled
    }

    fileprivate struct LocalizedLanguageCode: Comparable {
      let code: String
      let localized: String

      init(code: String) {
        self.code = code
        var localized = Locale.current.localizedString(forIdentifier: code) ?? ""
        if localized.isEmpty {
          localized = String(isoName(code))  // Fallback to iso_639-3.mo.
        }
        if localized.isEmpty {
          localized = String(format: NSLocalizedString("Unknown - %@", comment: ""), code)
        }
        self.localized = localized
      }

      public static func < (lhs: Self, rhs: Self) -> Bool {
        // Pin English.
        if lhs.code == en {
          return true
        }
        if rhs.code == en {
          return false
        }
        // Pin system language (or language assigned to Fcitx5).
        let curIdent = Locale.current.identifier.prefix(2)
        let le = lhs.code.prefix(2) == curIdent
        let re = rhs.code.prefix(2) == curIdent
        if le && !re {
          return true
        }
        if !le && re {
          return false
        }
        return lhs.localized.localizedCompare(rhs.localized) == .orderedAscending
      }
    }

    fileprivate func languages() -> [LocalizedLanguageCode] {
      return Array(availableIMs.keys)
        .filter {
          !(addIMOnlyShowCurrentLanguage ?? false) || languageCodeMatch($0, languagesOfEnabledIMs)
        }
        .map { LocalizedLanguageCode(code: $0) }
        .sorted()
    }
  }
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
