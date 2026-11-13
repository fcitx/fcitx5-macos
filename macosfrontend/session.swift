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
  public let generation: UInt64
}

public struct InputSessionToken: Hashable, Sendable {
  public let registration: InputSessionRegistration
  public let activationGeneration: UInt64
}

@MainActor
struct InputSessionPresentationUpdate {
  private let validate: () -> Bool

  init(validate: @escaping () -> Bool) { self.validate = validate }

  var isCurrent: Bool { validate() }
}

@MainActor
final class InputSessionPresentation {
  // Queries can reenter after a step has left the FIFO. A newer delivery for
  // this registration supersedes that in-flight presentation.
  private var revision: UInt64 = 0

  func beginUpdate(while isValid: @escaping () -> Bool) -> InputSessionPresentationUpdate {
    revision += 1
    let current = revision
    return InputSessionPresentationUpdate { [self] in revision == current && isValid() }
  }
}

// Controller is generic so lifecycle tests do not need an IMKServer or client.
// Production specializes the registry with IMKInputController.
@MainActor
final class InputSessionRegistry<Controller: AnyObject> {
  private struct Entry {
    weak var controller: Controller?
    let registration: InputSessionRegistration
    let presentation: InputSessionPresentation
  }

  private var entries: [InputSessionKey: Entry] = [:]
  private var registrationGeneration: UInt64 = 0
  private var activationGeneration: UInt64 = 0
  private var selected: InputSessionToken?
  private var closing: Set<InputSessionToken> = []

  var closingTokens: Set<InputSessionToken> { closing }

  var activeToken: InputSessionToken? {
    guard let selected, lookup(selected) != nil else { return nil }
    return selected
  }

  func register(_ key: InputSessionKey, controller: Controller) -> InputSessionRegistration? {
    if let entry = entries[key], let existing = entry.controller {
      // A duplicate must not silently replace another live controller.
      return existing === controller ? entry.registration : nil
    }
    registrationGeneration += 1
    let registration = InputSessionRegistration(key: key, generation: registrationGeneration)
    entries[key] = Entry(
      controller: controller, registration: registration, presentation: InputSessionPresentation())
    return registration
  }

  func lookup(_ registration: InputSessionRegistration) -> Controller? {
    guard let entry = entries[registration.key], entry.registration == registration
    else { return nil }
    return entry.controller
  }

  func lookup(_ token: InputSessionToken) -> Controller? {
    guard selected == token else { return nil }
    return lookup(token.registration)
  }

  func presentation(_ registration: InputSessionRegistration) -> InputSessionPresentation? {
    guard lookup(registration) != nil else { return nil }
    return entries[registration.key]?.presentation
  }

  func lookupForOutput(_ token: InputSessionToken) -> Controller? {
    guard selected == token || closing.contains(token) else { return nil }
    return lookup(token.registration)
  }

  func finishClosing(_ token: InputSessionToken) {
    closing.remove(token)
  }

  @discardableResult
  func activate(_ registration: InputSessionRegistration) -> InputSessionToken? {
    guard lookup(registration) != nil else { return nil }
    if let selected, selected.registration == registration { return selected }
    if let selected { closing.insert(selected) }
    activationGeneration += 1
    let token = InputSessionToken(
      registration: registration, activationGeneration: activationGeneration)
    selected = token
    return token
  }

  func deactivate(_ registration: InputSessionRegistration) {
    guard selected?.registration == registration else { return }
    if let selected { closing.insert(selected) }
    selected = nil
  }

  @discardableResult
  func unregister(_ registration: InputSessionRegistration) -> Bool {
    guard entries[registration.key]?.registration == registration else { return false }
    entries.removeValue(forKey: registration.key)
    deactivate(registration)
    closing = closing.filter { $0.registration != registration }
    return true
  }
}
