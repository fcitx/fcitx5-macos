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
  private var isDraining = false

  init(
    registry: InputSessionRegistry<Controller>, queue: InputSessionOutputQueue,
    deliver: @escaping (Controller, InputSessionOutput.Operation) -> Void
  ) {
    self.registry = registry
    self.queue = queue
    self.deliver = deliver
  }

  func drain() {
    guard !isDraining else { return }
    isDraining = true
    defer { isDraining = false }
    while true {
      let pending = queue.takePending()
      guard !pending.isEmpty else { return }
      for output in pending {
        if output.operation == .close {
          registry.finishClosing(output.token)
        } else if let controller = registry.lookupForOutput(output.token) {
          deliver(controller, output.operation)
        }
      }
    }
  }
}
