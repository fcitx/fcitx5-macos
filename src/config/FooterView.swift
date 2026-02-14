import SwiftUI

struct FooterView: View {
  @ObservedObject var manager: ConfigManager
  let onClose: () -> Void

  var body: some View {
    HStack {
      Button {
        manager.undo()
      } label: {
        Image(systemName: "arrow.uturn.left")
      }.disabled(manager.undoStack.count == 0)

      Button {
        manager.redo()
      } label: {
        Image(systemName: "arrow.uturn.right")
      }.disabled(manager.redoStack.count == 0)

      Button {
        manager.reset()
      } label: {
        Text("Reset to default").tooltip(
          NSLocalizedString(
            "Reset current page. To reset a single item/group, right click on its label.",
            comment: ""
          ))
      }

      Spacer()

      Button {
        onClose()
      } label: {
        Text("Close")
      }
    }.padding()
  }
}
