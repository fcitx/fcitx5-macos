import os

struct InputSessionOutput: Sendable {
  enum Operation: Equatable, Sendable {
    case commit(String)
    case commitAndPreedit(commit: String, preedit: String, caret: Int, dummy: Bool)
    case close
  }

  let token: InputSessionToken
  let operation: Operation
}

// Only value snapshots cross the thread boundary. No IMK object or actor state
// is accessed while holding this lock.
final class InputSessionOutputQueue: Sendable {
  private struct State: Sendable {
    var pending: [InputSessionOutput] = []
    var drainScheduled = false
  }

  private let state = OSAllocatedUnfairLock(initialState: State())

  func enqueue(_ output: InputSessionOutput) -> Bool {
    return state.withLock {
      $0.pending.append(output)
      guard !$0.drainScheduled else { return false }
      $0.drainScheduled = true
      return true
    }
  }

  func takePending() -> [InputSessionOutput] {
    return state.withLock {
      let pending = $0.pending
      $0.pending.removeAll(keepingCapacity: true)
      $0.drainScheduled = false
      return pending
    }
  }

  func clear() {
    state.withLock {
      $0.pending.removeAll()
      $0.drainScheduled = false
    }
  }
}

@MainActor
final class InputSessionOutputDispatcher<Controller: AnyObject> {
  private let registry: InputSessionRegistry<Controller>
  private let queue: InputSessionOutputQueue
  private let deliver: (Controller, InputSessionOutput.Operation) -> Void
  // Keep the unconsumed steps visible to reentrant synchronous transitions.
  private var pending: ArraySlice<InputSessionOutput> = []

  init(
    registry: InputSessionRegistry<Controller>, queue: InputSessionOutputQueue,
    deliver: @escaping (Controller, InputSessionOutput.Operation) -> Void
  ) {
    self.registry = registry
    self.queue = queue
    self.deliver = deliver
  }

  func drain() {
    while true {
      if pending.isEmpty {
        pending = ArraySlice(
          queue.takePending().flatMap { output in
            guard
              case .commitAndPreedit(let commit, let preedit, let caret, let dummy) =
                output.operation, !commit.isEmpty
            else { return [output] }
            // insertText can reenter before the associated preedit is applied.
            // Publish that preedit as the next step before calling the client.
            return [
              InputSessionOutput(token: output.token, operation: .commit(commit)),
              InputSessionOutput(
                token: output.token,
                operation: .commitAndPreedit(
                  commit: "", preedit: preedit, caret: caret, dummy: dummy)),
            ]
          })
      }
      // Advance before delivery so nested drains cannot deliver this step twice.
      guard let output = pending.popFirst() else { return }
      if output.operation == .close {
        registry.finishClosing(output.token)
      } else if let controller = registry.lookupForOutput(output.token) {
        deliver(controller, output.operation)
      }
    }
  }
}
