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
      controller, operation in
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
    testSynchronousReentry(combined: false)
    testSynchronousReentry(combined: true)
    testSynchronousReentry(combined: true, outputAfterSync: true)
    let registry = InputSessionRegistry<Controller>()
    let queue = InputSessionOutputQueue()
    let dispatcher = InputSessionOutputDispatcher(registry: registry, queue: queue) {
      controller, operation in
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
    ) { controller, operation in
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
