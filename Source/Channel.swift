
public protocol Channel: AnyObject {

    typealias Identifier = [String: String]

    var name: String { get }
    var identifier: Identifier? { get }

    var cable: Cable? { get set }

    func didConnect()
    func didDisconnect()
    func wasRejected()

    func didReceive(message: [String: Any])
}

extension Channel {

    var isConnected: Bool {
        guard let cable = self.cable else { return false }
        return cable.isConnected
    }

    var identifierPayload: String {
        var identifier = self.identifier ?? [:]
        identifier["channel"] = self.name
        return try! JSONEncoder().encodeString(identifier)
    }

    // MARK: - Subscribing

    public func subscribe(on cable: Cable) {
        self.cable = cable
        cable.subscribe(to: self)
    }

    public func unsubscribe() {
        guard let cable = self.cable else { return }
        cable.unsubscribe(from: self)

        self.cable = nil
    }

    var isSubscribed: Bool {
        guard let cable = self.cable else { return false }
        guard cable.isConnected else { return false }

        return cable.isSubscribed(to: self)
    }

    // MARK: - Receiving

    // MARK: - Sending

    public func perform(action: String, data: [String: Any] = [:]) throws {
        guard let cable = self.cable else { return }

        let action = try MessageAction(channel: self, action: action, data: data)
        try cable.transmit(action)
    }

    public func performWhenConnected(action: String, data: [String: Any]) throws {
        guard let cable = self.cable else { return }

        let action = try MessageAction(channel: self, action: action, data: data)
        cable.transmitWhenConnected(action)
    }

    // MARK: - Callbacks

    internal func subscriptionConfirmed(on cable: Cable) {
        self.didConnect()
    }

    internal func subscriptionRejected(on cable: Cable) {
        self.wasRejected()
    }

    internal func cableDisconnected() {
        self.didDisconnect()
    }

    internal func received(message: MessageMessage) {
        self.didReceive(message: message.message)
    }
}

func ==(lhs: Channel, rhs: Channel) -> Bool {
    return lhs == (rhs.name, rhs.identifier)
}

func ==(lhs: Channel, rhs: (name: String, identifier: Channel.Identifier?)) -> Bool {
    if lhs.identifier != nil || rhs.identifier != nil {
        guard let lhsID = lhs.identifier, let rhsID = rhs.identifier else { return false }
        guard lhsID == rhsID else { return false }
    }

    return lhs.name == rhs.name
}
