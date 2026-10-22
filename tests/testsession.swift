private final class Controller {
  let appId = "same.app"
}

@main
struct SessionTests {
  @MainActor
  static func main() async {
    let registry = InputSessionRegistry<Controller>()
    let keyA = InputSessionKey(Array(repeating: 0, count: 16))
    var bytesB = keyA.bytes
    bytesB[15] = 1
    let keyB = InputSessionKey(bytesB)
    let a = Controller()
    let b = Controller()

    precondition(registry.register(keyA, controller: a) == nil)
    registry.beginRuntime()
    let registrationA = registry.register(keyA, controller: a)!
    registry.beginRuntime()
    precondition(registry.register(keyA, controller: a) == registrationA)
    precondition(registry.register(keyA, controller: b) == nil)
    precondition(registry.lookup(registrationA) === a)
    precondition(registry.activeToken == nil)

    // The same app can have multiple ICUUIDs. The first handle can activate a
    // registered session even when activateServer was never called.
    let registrationB = registry.register(keyB, controller: b)!
    precondition(a.appId == b.appId)
    precondition(registry.lookup(registrationB) === b)
    let firstA = registry.activate(registrationA)!
    precondition(registry.activate(registrationA) == firstA)
    precondition(registry.lookup(firstA) === a)
    let firstB = registry.activate(registrationB)!
    precondition(registry.lookup(firstA) == nil)
    registry.deactivate(registrationA)
    precondition(registry.activeToken == firstB)
    let secondA = registry.activate(registrationA)!
    precondition(secondA != firstA)
    precondition(registry.lookup(firstA) == nil)
    registry.deactivate(registrationA)
    registry.deactivate(registrationA)
    precondition(registry.lookup(secondA) == nil)
    precondition(registry.lookup(registrationA) === a)

    // Re-registration cannot make an old token valid or let a delayed cleanup
    // unregister the replacement.
    precondition(registry.unregister(registrationA))
    precondition(!registry.unregister(registrationA))
    let replacementA = registry.register(keyA, controller: a)!
    precondition(replacementA != registrationA)
    precondition(!registry.unregister(registrationA))
    precondition(registry.lookup(replacementA) === a)
    precondition(registry.activate(registrationA) == nil)

    // The registry and its active token must not retain a controller.
    var temporary: Controller? = Controller()
    precondition(registry.unregister(replacementA))
    let weakRegistration = registry.register(keyA, controller: temporary!)!
    let weakToken = registry.activate(weakRegistration)!
    temporary = nil
    precondition(registry.lookup(weakRegistration) == nil)
    precondition(registry.lookup(weakToken) == nil)
    precondition(registry.activeToken == nil)
    let afterDeinit = registry.register(keyA, controller: a)!
    precondition(!registry.unregister(weakRegistration))
    precondition(registry.lookup(afterDeinit) === a)

    // Simulate a MainActor task arriving after a lifecycle change. Its captured
    // token is a value; the task does not keep the controller alive.
    let queuedToken = registry.activate(afterDeinit)!
    let lateLookup = Task { @MainActor in registry.lookup(queuedToken) != nil }
    registry.endRuntime()
    let foundAfterTeardown = await lateLookup.value
    precondition(!foundAfterTeardown)
    registry.endRuntime()
    precondition(registry.activeToken == nil)
    precondition(registry.lookup(registrationB) == nil)
    precondition(!registry.unregister(afterDeinit))
    precondition(registry.register(keyA, controller: a) == nil)

    registry.beginRuntime()
    let restarted = registry.register(keyA, controller: a)!
    precondition(restarted.runtimeEpoch != afterDeinit.runtimeEpoch)
    precondition(registry.lookup(queuedToken) == nil)
    precondition(!registry.unregister(afterDeinit))
    precondition(registry.lookup(restarted) === a)

    // Registration credentials can cross threads without transferring an IMK
    // object. Cleanup still runs on MainActor and checks the runtime epoch.
    let returned = await Task.detached { restarted }.value
    precondition(returned == restarted)
    precondition(registry.unregister(returned))
    registry.endRuntime()
  }
}
