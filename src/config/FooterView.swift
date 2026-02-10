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
        Text("Reset to default")
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
