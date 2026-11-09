private final class Client {
  var events: [String] = []
  var preedit = ""
}

private final class Controller {
  let client: Client?

  init(_ client: Client?) { self.client = client }
}

@main
struct SessionOutputTests {
  @MainActor
  static func testPresentationReentry(
    outerSynchronous: Bool, innerSynchronous: Bool, differentSession: Bool
  ) {
    let registry = InputSessionRegistry<Controller>()
    let queue = InputSessionOutputQueue()
    let client = Client()
    let otherClient = Client()
    let controller = Controller(client)
    let otherController = Controller(otherClient)
    registry.beginRuntime()
    let registration = registry.register(
      InputSessionKey(Array(repeating: 0, count: 16)), controller: controller)!
    let otherRegistration = registry.register(
      InputSessionKey(Array(repeating: 1, count: 16)), controller: otherController)!
    let token = registry.activate(registration)!
    // Keep A deliverable as a closing session while B is active.
    let otherToken = registry.activate(otherRegistration)!
    let innerRegistration = differentSession ? otherRegistration : registration
    let innerToken = differentSession ? otherToken : token
    let innerClient = differentSession ? otherClient : client
    var reenter: (() -> Void)?
    let deliver: (Client, InputSessionOutput.Operation, InputSessionPresentationUpdate) -> Void = {
      client, operation, update in
      guard update.isCurrent else { return }
      guard case .commitAndPreedit(_, let preedit, _, _) = operation else {
        preconditionFailure()
      }
      if preedit == "old" { reenter?() }
      // Model an IMK query returning after a nested input callback. The
      // dispatcher must invalidate this already-popped step for the same
      // registration, including across synchronous/asynchronous delivery.
      guard update.isCurrent else { return }
      client.preedit = preedit
      client.events.append("preedit:\(preedit)")
    }
    let dispatcher = InputSessionOutputDispatcher(registry: registry, queue: queue) {
      controller, operation, update in
      deliver(controller.client!, operation, update)
    }
    let newer = InputSessionOutput.Operation.commitAndPreedit(
      commit: "", preedit: "new", caret: 0, dummy: false)
    reenter = {
      if innerSynchronous {
        dispatcher.applySynchronous(
          at: queue.enqueueBoundary(), registration: innerRegistration, operation: newer
        ) { operation, update in deliver(innerClient, operation, update) }
      } else {
        _ = queue.enqueue(InputSessionOutput(token: innerToken, operation: newer))
        dispatcher.drain()
      }
    }
    let older = InputSessionOutput.Operation.commitAndPreedit(
      commit: "", preedit: "old", caret: 0, dummy: false)
    withExtendedLifetime((controller, otherController)) {
      if outerSynchronous {
        dispatcher.applySynchronous(
          at: queue.enqueueBoundary(), registration: registration, operation: older
        ) { operation, update in deliver(client, operation, update) }
      } else {
        _ = queue.enqueue(InputSessionOutput(token: token, operation: older))
        dispatcher.drain()
      }
    }
    reenter = nil
    precondition(client.events == ["preedit:\(differentSession ? "old" : "new")"])
    precondition(otherClient.events == (differentSession ? ["preedit:new"] : []))
  }

  @MainActor
  static func testPresentationLifetime() {
    let registry = InputSessionRegistry<Controller>()
    let controller = Controller(Client())
    registry.beginRuntime()
    let key = InputSessionKey(Array(repeating: 0, count: 16))
    let registration = registry.register(key, controller: controller)!
    let token = registry.activate(registration)!
    let presentation = registry.presentation(registration)!
    let update = presentation.beginUpdate { registry.lookupForOutput(token) != nil }
    precondition(update.isCurrent)
    registry.deactivate(registration)
    precondition(update.isCurrent)
    registry.finishClosing(token)
    precondition(!update.isCurrent)
    let synchronousUpdate = presentation.beginUpdate { registry.lookup(registration) != nil }
    precondition(synchronousUpdate.isCurrent)
    precondition(registry.unregister(registration))
    precondition(!synchronousUpdate.isCurrent)
    let replacement = registry.register(key, controller: controller)!
    precondition(replacement != registration)
    precondition(!synchronousUpdate.isCurrent)
    let replacementUpdate = registry.presentation(replacement)!.beginUpdate {
      registry.lookup(replacement) != nil
    }
    precondition(replacementUpdate.isCurrent)
    registry.endRuntime()
    precondition(!replacementUpdate.isCurrent)
  }

  @MainActor
  static func testSynchronousResponseReentry(earlierAsyncCommit: Bool, outputAfterInner: Bool) {
    let registry = InputSessionRegistry<Controller>()
    let queue = InputSessionOutputQueue()
    let client = Client()
    let controller = Controller(client)
    registry.beginRuntime()
    let registration = registry.register(
      InputSessionKey(Array(repeating: 0, count: 16)), controller: controller)!
    let token = registry.activate(registration)!
    var nestedTransition: (() -> Void)?
    let deliver: (InputSessionOutput.Operation, InputSessionPresentationUpdate) -> Void = {
      operation, update in
      guard update.isCurrent else { return }
      switch operation {
      case .commit(let text):
        client.events.append("commit:\(text)")
        if text == "outer" { nestedTransition?() }
      case .commitAndPreedit(let commit, let preedit, _, _):
        precondition(commit.isEmpty)
        client.preedit = preedit
        client.events.append("preedit:\(preedit)")
      case .close:
        preconditionFailure()
      }
    }
    let dispatcher = InputSessionOutputDispatcher(registry: registry, queue: queue) {
      _, operation, update in
      deliver(operation, update)
    }
    nestedTransition = {
      dispatcher.drain()
      let innerBoundary = queue.enqueueBoundary()
      if outputAfterInner {
        _ = queue.enqueue(
          InputSessionOutput(
            token: token,
            operation: .commitAndPreedit(commit: "", preedit: "after", caret: 0, dummy: false)))
      }
      dispatcher.applySynchronous(
        at: innerBoundary, registration: registration,
        operation: .commitAndPreedit(commit: "", preedit: "new", caret: 0, dummy: false),
        deliver: deliver)
    }
    if earlierAsyncCommit {
      _ = queue.enqueue(InputSessionOutput(token: token, operation: .commit("outer")))
    }
    let outerBoundary = queue.enqueueBoundary()
    _ = queue.enqueue(
      InputSessionOutput(
        token: token,
        operation: .commitAndPreedit(commit: "", preedit: "queued-new", caret: 0, dummy: false)))
    withExtendedLifetime(controller) {
      dispatcher.applySynchronous(
        at: outerBoundary, registration: registration,
        operation: .commitAndPreedit(
          commit: earlierAsyncCommit ? "" : "outer", preedit: "old", caret: 0, dummy: false),
        deliver: deliver)
    }
    nestedTransition = nil
    precondition(client.preedit == (outputAfterInner ? "after" : "new"))
    precondition(
      client.events == ["commit:outer", "preedit:old", "preedit:queued-new", "preedit:new"]
        + (outputAfterInner ? ["preedit:after"] : []))
  }

  @MainActor
  static func testCoreBoundary() async {
    let registry = InputSessionRegistry<Controller>()
    let queue = InputSessionOutputQueue()
    let client = Client()
    let controller = Controller(client)
    registry.beginRuntime()
    let registration = registry.register(
      InputSessionKey(Array(repeating: 0, count: 16)), controller: controller)!
    let token = registry.activate(registration)!
    let dispatcher = InputSessionOutputDispatcher(registry: registry, queue: queue) {
      _, operation, _ in
      guard case .commitAndPreedit(_, let preedit, _, _) = operation else { preconditionFailure() }
      client.preedit = preedit
      client.events.append("async:\(preedit)")
    }
    dispatcher.drain()
    // The core emits older output after the main thread's initial drain, then
    // returns the Backspace response together with its FIFO position.
    let boundary = await Task.detached {
      _ = queue.enqueue(
        InputSessionOutput(
          token: token,
          operation: .commitAndPreedit(commit: "", preedit: "ni", caret: 0, dummy: false)))
      return queue.enqueueBoundary()
    }.value
    dispatcher.applySynchronous(
      at: boundary, registration: registration,
      operation: .commitAndPreedit(commit: "", preedit: "n", caret: 0, dummy: false)
    ) { _, _ in
      client.preedit = "n"
      client.events.append("sync:n")
    }
    precondition(client.preedit == "n")
    precondition(client.events == ["async:ni", "sync:n"])

    let nextBoundary = queue.enqueueBoundary()
    _ = queue.enqueue(
      InputSessionOutput(
        token: token,
        operation: .commitAndPreedit(commit: "", preedit: "next", caret: 0, dummy: false)))
    // A scheduled drain cannot pass a result that the caller has not published.
    dispatcher.drain()
    precondition(client.preedit == "n")
    dispatcher.applySynchronous(
      at: nextBoundary, registration: registration,
      operation: .commitAndPreedit(commit: "", preedit: "ne", caret: 0, dummy: false)
    ) { _, _ in
      client.preedit = "ne"
      client.events.append("sync:ne")
    }
    precondition(client.events == ["async:ni", "sync:n", "sync:ne", "async:next"])

    // Discarding a response (invalid context or a side-effect-only key) must
    // release its boundary and allow later output through.
    let invalidBoundary = queue.enqueueBoundary()
    _ = queue.enqueue(
      InputSessionOutput(
        token: token,
        operation: .commitAndPreedit(commit: "", preedit: "after-discard", caret: 0, dummy: false)))
    dispatcher.applySynchronous(at: invalidBoundary, registration: nil, operation: nil) { _, _ in
      preconditionFailure()
    }
    precondition(client.preedit == "after-discard")
    precondition(client.events.last == "async:after-discard")
    precondition(registry.lookup(token) === controller)

    // Completion must release a borrowed client even when a later unpublished
    // marker keeps the consumed ArraySlice storage alive.
    var borrowed: Controller? = Controller(Client())
    let borrowedRegistration = registry.register(
      InputSessionKey(Array(repeating: 1, count: 16)), controller: borrowed!)!
    let borrowedBoundary = queue.enqueueBoundary()
    let laterBoundary = queue.enqueueBoundary()
    dispatcher.applySynchronous(
      at: borrowedBoundary, registration: borrowedRegistration, operation: .commit("borrowed")
    ) {
      [borrowed = borrowed!] _, _ in
      borrowed.client?.events.append("delivered")
    }
    borrowed = nil
    precondition(registry.lookup(borrowedRegistration) == nil)
    dispatcher.applySynchronous(at: laterBoundary, registration: nil, operation: nil) { _, _ in
      preconditionFailure()
    }

    let discardedBoundary = queue.enqueueBoundary()
    queue.clear()
    precondition(queue.enqueueBoundary() > discardedBoundary)
  }

  @MainActor
  static func testSynchronousReentry(combined: Bool, outputAfterSync: Bool = false) {
    let registry = InputSessionRegistry<Controller>()
    let queue = InputSessionOutputQueue()
    let client = Client()
    let controller = Controller(client)
    registry.beginRuntime()
    let registration = registry.register(
      InputSessionKey(Array(repeating: 0, count: 16)), controller: controller)!
    let token = registry.activate(registration)!
    var synchronousTransition: (() -> Void)?
    let dispatcher = InputSessionOutputDispatcher(registry: registry, queue: queue) {
      controller, operation, _ in
      guard let client = controller.client else { preconditionFailure() }
      switch operation {
      case .commit(let text):
        client.events.append("commit:\(text)")
        synchronousTransition?()
      case .commitAndPreedit(let commit, let preedit, _, _):
        if !commit.isEmpty {
          client.events.append("commit:\(commit)")
          synchronousTransition?()
        }
        client.preedit = preedit
        client.events.append("preedit:\(preedit)")
      case .close:
        preconditionFailure()
      }
    }
    synchronousTransition = {
      // Model processKey/commitComposition: drain older output, apply the
      // synchronous response, then drain output produced after that response.
      dispatcher.drain()
      client.preedit = "new"
      client.events.append("sync:new")
      if outputAfterSync {
        _ = queue.enqueue(
          InputSessionOutput(
            token: token,
            operation: .commitAndPreedit(commit: "", preedit: "after", caret: 0, dummy: false)))
      }
      dispatcher.drain()
    }
    if combined {
      _ = queue.enqueue(
        InputSessionOutput(
          token: token,
          operation: .commitAndPreedit(commit: "trigger", preedit: "old", caret: 0, dummy: false)))
    } else {
      _ = queue.enqueue(InputSessionOutput(token: token, operation: .commit("trigger")))
      _ = queue.enqueue(
        InputSessionOutput(
          token: token,
          operation: .commitAndPreedit(commit: "", preedit: "old", caret: 0, dummy: false)))
    }
    withExtendedLifetime(controller) { dispatcher.drain() }
    synchronousTransition = nil
    precondition(
      client.preedit == (outputAfterSync ? "after" : "new"),
      "Queued preedit overwrote the reentrant sync result")
    let expected = ["commit:trigger", "preedit:old", "sync:new"]
    precondition(client.events == expected + (outputAfterSync ? ["preedit:after"] : []))
  }

  @MainActor
  static func main() async {
    for outerSynchronous in [false, true] {
      for innerSynchronous in [false, true] {
        for differentSession in [false, true] {
          testPresentationReentry(
            outerSynchronous: outerSynchronous, innerSynchronous: innerSynchronous,
            differentSession: differentSession)
        }
      }
    }
    testPresentationLifetime()
    testSynchronousResponseReentry(earlierAsyncCommit: false, outputAfterInner: false)
    testSynchronousResponseReentry(earlierAsyncCommit: true, outputAfterInner: false)
    testSynchronousResponseReentry(earlierAsyncCommit: false, outputAfterInner: true)
    await testCoreBoundary()
    testSynchronousReentry(combined: false)
    testSynchronousReentry(combined: true)
    testSynchronousReentry(combined: true, outputAfterSync: true)
    let registry = InputSessionRegistry<Controller>()
    let queue = InputSessionOutputQueue()
    let dispatcher = InputSessionOutputDispatcher(registry: registry, queue: queue) {
      controller, operation, _ in
      guard let client = controller.client else { return }
      switch operation {
      case .commit(let text):
        client.events.append("commit:\(text)")
      case .commitAndPreedit(let commit, let preedit, _, _):
        if !commit.isEmpty { client.events.append("commit:\(commit)") }
        client.events.append("preedit:\(preedit)")
      case .close:
        preconditionFailure("Close markers must not reach the client")
      }
    }
    func enqueue(_ token: InputSessionToken, _ operation: InputSessionOutput.Operation) {
      _ = queue.enqueue(InputSessionOutput(token: token, operation: operation))
    }
    func key(_ value: UInt8) -> InputSessionKey {
      return InputSessionKey(Array(repeating: value, count: 16))
    }

    registry.beginRuntime()
    let clientA = Client()
    let clientB = Client()
    let a = Controller(clientA)
    let b = Controller(clientB)
    let registrationA = registry.register(key(0), controller: a)!
    let registrationB = registry.register(key(1), controller: b)!
    let firstA = registry.activate(registrationA)!

    // Candidate clicks can commit and then separately update preedit. Both
    // forms share the same FIFO and are delivered to the original session.
    precondition(queue.enqueue(InputSessionOutput(token: firstA, operation: .commit("first"))))
    precondition(
      !queue.enqueue(InputSessionOutput(token: firstA, operation: .commit("second"))))
    enqueue(firstA, .commitAndPreedit(commit: "third", preedit: "next", caret: 0, dummy: false))
    dispatcher.drain()
    precondition(
      clientA.events == ["commit:first", "commit:second", "commit:third", "preedit:next"])
    precondition(clientB.events.isEmpty)

    let firstB = registry.activate(registrationB)!
    precondition(registry.lookup(firstA) == nil)
    enqueue(firstA, .commit("focus-out"))
    enqueue(firstA, .commitAndPreedit(commit: "", preedit: "", caret: 0, dummy: false))
    enqueue(firstA, .close)
    enqueue(firstA, .commit("too late"))
    enqueue(firstB, .commit("B"))
    dispatcher.drain()
    precondition(clientA.events.suffix(2) == ["commit:focus-out", "preedit:"])
    precondition(clientB.events == ["commit:B"])
    precondition(registry.lookupForOutput(firstA) == nil)

    // A -> B -> A must not revive the first A generation, and an old close
    // marker must not close the new A generation.
    let secondA = registry.activate(registrationA)!
    enqueue(firstB, .close)
    enqueue(firstA, .commit("old A"))
    enqueue(firstA, .close)
    enqueue(secondA, .commit("new A"))
    dispatcher.drain()
    precondition(clientA.events.last == "commit:new A")
    precondition(!clientA.events.contains("commit:old A"))
    precondition(registry.lookup(secondA) === a)

    // Queued snapshots must not keep a controller alive or fall back to A.
    let abandonedClient = Client()
    var abandoned: Controller? = Controller(abandonedClient)
    let abandonedRegistration = registry.register(key(2), controller: abandoned!)!
    let abandonedToken = registry.activate(abandonedRegistration)!
    enqueue(secondA, .close)
    enqueue(abandonedToken, .commit("abandoned"))
    abandoned = nil
    dispatcher.drain()
    precondition(abandonedClient.events.isEmpty)
    precondition(clientA.events.last == "commit:new A")

    let noClient = Controller(nil)
    let noClientRegistration = registry.register(key(3), controller: noClient)!
    let noClientToken = registry.activate(noClientRegistration)!
    enqueue(noClientToken, .commit("missing client"))
    dispatcher.drain()
    precondition(clientA.events.last == "commit:new A")
    precondition(clientB.events == ["commit:B"])

    let removedToken = registry.activate(registrationB)!
    enqueue(removedToken, .commit("removed"))
    precondition(registry.unregister(registrationB))
    dispatcher.drain()
    precondition(clientB.events == ["commit:B"])

    enqueue(secondA, .commit("stopped"))
    registry.endRuntime()
    registry.beginRuntime()
    let restarted = registry.register(key(0), controller: a)!
    let restartedToken = registry.activate(restarted)!
    enqueue(secondA, .close)
    enqueue(restartedToken, .commit("restarted"))
    dispatcher.drain()
    precondition(clientA.events.last == "commit:restarted")
    precondition(!clientA.events.contains("commit:stopped"))

    // The ingress is callable from background producers. No payload is lost,
    // and each producer's order is preserved when the main actor drains it.
    await withTaskGroup(of: Void.self) { group in
      for producer in 0..<2 {
        group.addTask {
          for index in 0..<100 {
            _ = queue.enqueue(
              InputSessionOutput(token: restartedToken, operation: .commit("\(producer)-\(index)")))
          }
        }
      }
    }
    let beforeConcurrentDelivery = clientA.events.count
    dispatcher.drain()
    let concurrentEvents = Array(clientA.events.dropFirst(beforeConcurrentDelivery))
    precondition(concurrentEvents.count == 200)
    for producer in 0..<2 {
      precondition(
        concurrentEvents.filter { $0.hasPrefix("commit:\(producer)-") }
          == (0..<100).map { "commit:\(producer)-\($0)" })
    }

    // Client callbacks may enqueue more work and request another drain. The
    // current batch still precedes that work, without holding the ingress lock.
    let reentrantQueue = InputSessionOutputQueue()
    var nestedDrain: (() -> Void)?
    let reentrantDispatcher = InputSessionOutputDispatcher(
      registry: registry, queue: reentrantQueue
    ) { controller, operation, _ in
      guard case .commit(let text) = operation else { preconditionFailure() }
      controller.client?.events.append(text)
      if text == "outer" {
        _ = reentrantQueue.enqueue(
          InputSessionOutput(token: restartedToken, operation: .commit("nested")))
        nestedDrain?()
      }
    }
    nestedDrain = { reentrantDispatcher.drain() }
    _ = reentrantQueue.enqueue(
      InputSessionOutput(token: restartedToken, operation: .commit("outer")))
    _ = reentrantQueue.enqueue(
      InputSessionOutput(token: restartedToken, operation: .commit("tail")))
    reentrantDispatcher.drain()
    nestedDrain = nil
    precondition(clientA.events.suffix(3) == ["outer", "tail", "nested"])

    enqueue(restartedToken, .commit("cleared"))
    registry.endRuntime()
    queue.clear()
    dispatcher.drain()
    precondition(clientA.events.count == beforeConcurrentDelivery + 203)
  }
}
