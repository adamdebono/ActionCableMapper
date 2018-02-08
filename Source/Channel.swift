
public protocol Channel: AnyObject {

    typealias Identifier = [String: String]

    var name: String { get }
    var identifier: Identifier? { get }

    weak var cable: Cable? { get set }

    func didConnect()
    func didDisconnect()
    func wasRejected()

    func didReceive()
}

extension Channel {

    var isConnected: Bool {
        return self.cable != nil
    }

    var identifierPayload: String {
        var identifier = self.identifier ?? [:]
        identifier["channel"] = self.name
        return try! JSONEncoder().encodeString(identifier)
    }

    // MARK: - Subscribing

    public func subscribe(on cable: Cable) {
        cable.subscribe(to: self)
    }

    public func unsubscribe() {
        guard let cable = self.cable else { return }
        cable.unsubscribe(from: self)
    }

    // MARK: - Receiving

    // MARK: - Sending

    public func perform() {

    }

    // MARK: - Callbacks

    internal func subscriptionConfirmed(on cable: Cable) {
        self.cable = cable

        self.didConnect()
    }

    internal func subscriptionRejected(on cable: Cable) {
        self.wasRejected()
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
