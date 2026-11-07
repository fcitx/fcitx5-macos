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
  enum Entry: Sendable {
    case output(InputSessionOutput)
    case boundary(UInt64)
  }

  private struct State: Sendable {
    var pending: [Entry] = []
    var drainScheduled = false
    var nextBoundary: UInt64 = 0
  }

  private let state = OSAllocatedUnfairLock(initialState: State())

  func enqueue(_ output: InputSessionOutput) -> Bool {
    return state.withLock {
      $0.pending.append(.output(output))
      guard !$0.drainScheduled else { return false }
      $0.drainScheduled = true
      return true
    }
  }

  func enqueueBoundary() -> UInt64 {
    return state.withLock {
      $0.nextBoundary += 1
      let id = $0.nextBoundary
      $0.pending.append(.boundary(id))
      // The waiting synchronous caller will publish and drain this marker.
      return id
    }
  }

  func takePending() -> [Entry] {
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
  private final class SynchronousResponse {
    let operation: InputSessionOutput.Operation?
    var deliver: ((InputSessionOutput.Operation) -> Void)?
    var completed = false

    init(
      operation: InputSessionOutput.Operation?,
      deliver: @escaping (InputSessionOutput.Operation) -> Void
    ) {
      self.operation = operation
      self.deliver = deliver
    }
  }

  private enum Step {
    case output(InputSessionOutput)
    case boundary(UInt64)
    case synchronous(SynchronousResponse, InputSessionOutput.Operation)
    case completion(SynchronousResponse)
  }

  private let registry: InputSessionRegistry<Controller>
  private let queue: InputSessionOutputQueue
  private let deliver: (Controller, InputSessionOutput.Operation) -> Void
  // Keep the unconsumed steps visible to reentrant synchronous transitions.
  private var pending: ArraySlice<Step> = []
  private var synchronousResponses: [UInt64: SynchronousResponse] = [:]

  init(
    registry: InputSessionRegistry<Controller>, queue: InputSessionOutputQueue,
    deliver: @escaping (Controller, InputSessionOutput.Operation) -> Void
  ) {
    self.registry = registry
    self.queue = queue
    self.deliver = deliver
  }

  func applySynchronous(
    at boundary: UInt64, operation: InputSessionOutput.Operation?,
    deliver: @escaping (InputSessionOutput.Operation) -> Void
  ) {
    let response = SynchronousResponse(operation: operation, deliver: deliver)
    precondition(synchronousResponses[boundary] == nil)
    // Publish the entire response before draining anything that can call a
    // client. A nested transition must see the outer response's preedit too.
    synchronousResponses[boundary] = response
    defer { synchronousResponses.removeValue(forKey: boundary) }
    drain()
    precondition(response.completed, "Synchronous output boundary was not reached")
  }

  private func operations(_ operation: InputSessionOutput.Operation) -> [InputSessionOutput
    .Operation]
  {
    guard case .commitAndPreedit(let commit, let preedit, let caret, let dummy) = operation,
      !commit.isEmpty
    else { return [operation] }
    return [
      .commit(commit),
      .commitAndPreedit(commit: "", preedit: preedit, caret: caret, dummy: dummy),
    ]
  }

  func drain() {
    while true {
      if pending.isEmpty {
        pending = ArraySlice(
          queue.takePending().flatMap { entry -> [Step] in
            switch entry {
            case .output(let output):
              return operations(output.operation).map {
                .output(InputSessionOutput(token: output.token, operation: $0))
              }
            case .boundary(let id):
              return [.boundary(id)]
            }
          })
      }
      // A scheduled drain may run before the caller has decoded the JSON.
      // Leave the marker in place until its synchronous response is published.
      if let first = pending.first, case .boundary(let id) = first,
        synchronousResponses[id] == nil
      {
        return
      }
      // Advance before delivery so nested drains cannot deliver this step twice.
      guard let step = pending.popFirst() else { return }
      switch step {
      case .output(let output):
        if output.operation == .close {
          registry.finishClosing(output.token)
        } else if let controller = registry.lookupForOutput(output.token) {
          deliver(controller, output.operation)
        }
      case .boundary(let id):
        guard let response = synchronousResponses.removeValue(forKey: id) else {
          preconditionFailure("Unpublished synchronous response")
        }
        let steps = response.operation.map { operations($0) } ?? []
        pending = ArraySlice(
          steps.map { Step.synchronous(response, $0) }
            + [.completion(response)] + pending)
      case .synchronous(let response, let operation):
        response.deliver?(operation)
      case .completion(let response):
        // An ArraySlice can retain consumed elements. Release borrowed IMK
        // clients even if a later unpublished boundary stops this drain.
        response.deliver = nil
        response.completed = true
      }
    }
  }
}
