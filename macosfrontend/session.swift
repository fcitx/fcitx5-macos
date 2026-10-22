// ICUUID remains the session identity. The counters only reject stale work.
public struct InputSessionKey: Hashable, Sendable {
  public let bytes: [UInt8]

  public init(_ bytes: [UInt8]) {
    precondition(bytes.count == 16)
    self.bytes = bytes
  }
}

public struct InputSessionRegistration: Hashable, Sendable {
  public let key: InputSessionKey
  public let runtimeEpoch: UInt64
  public let generation: UInt64
}

public struct InputSessionToken: Hashable, Sendable {
  public let registration: InputSessionRegistration
  public let activationGeneration: UInt64
}

// Controller is generic so lifecycle tests do not need an IMKServer or client.
// Production specializes the registry with IMKInputController.
@MainActor
final class InputSessionRegistry<Controller: AnyObject> {
  private struct Entry {
    weak var controller: Controller?
    let registration: InputSessionRegistration
  }

  private var entries: [InputSessionKey: Entry] = [:]
  private var runtimeEpoch: UInt64 = 0
  private var registrationGeneration: UInt64 = 0
  private var activationGeneration: UInt64 = 0
  private var isRunning = false
  private var selected: InputSessionToken?

  var activeToken: InputSessionToken? {
    guard let selected, lookup(selected) != nil else { return nil }
    return selected
  }

  func beginRuntime() {
    guard !isRunning else { return }
    runtimeEpoch += 1
    isRunning = true
  }

  func endRuntime() {
    isRunning = false
    selected = nil
    entries.removeAll()
  }

  func register(_ key: InputSessionKey, controller: Controller) -> InputSessionRegistration? {
    guard isRunning else { return nil }
    if let entry = entries[key], let existing = entry.controller {
      // A duplicate must not silently replace another live controller.
      return existing === controller ? entry.registration : nil
    }
    registrationGeneration += 1
    let registration = InputSessionRegistration(
      key: key, runtimeEpoch: runtimeEpoch, generation: registrationGeneration)
    entries[key] = Entry(controller: controller, registration: registration)
    return registration
  }

  func lookup(_ registration: InputSessionRegistration) -> Controller? {
    guard isRunning, registration.runtimeEpoch == runtimeEpoch,
      let entry = entries[registration.key], entry.registration == registration
    else { return nil }
    return entry.controller
  }

  func lookup(_ token: InputSessionToken) -> Controller? {
    guard selected == token else { return nil }
    return lookup(token.registration)
  }

  @discardableResult
  func activate(_ registration: InputSessionRegistration) -> InputSessionToken? {
    guard lookup(registration) != nil else { return nil }
    if let selected, selected.registration == registration { return selected }
    activationGeneration += 1
    let token = InputSessionToken(
      registration: registration, activationGeneration: activationGeneration)
    selected = token
    return token
  }

  func deactivate(_ registration: InputSessionRegistration) {
    guard selected?.registration == registration else { return }
    selected = nil
  }

  @discardableResult
  func unregister(_ registration: InputSessionRegistration) -> Bool {
    guard isRunning, entries[registration.key]?.registration == registration else { return false }
    entries.removeValue(forKey: registration.key)
    deactivate(registration)
    return true
  }
}
