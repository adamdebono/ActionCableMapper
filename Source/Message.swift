
public enum MessageType: String, Codable {
    case cancelSubscription = "cancel_subscription"
    case command = "command"
    case confirmSubscription = "confirm_subscription"
    case hibernateSubscription = "hibernate_subscription"
    case message = "message"
    case ping = "ping"
    case rejectSubscription = "reject_subscription"
    case welcome = "welcome"
}

public protocol Message: Codable {
    var kind: MessageType { get }
}

// MARK: - Helper Functions

internal func decodeMessage(_ text: String) throws -> Message {
    let data = text.data(using: .utf8)!
    guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { throw CodingError.invalidType }

    guard let typeString = json["type"] as? String else { throw CodingError.missingData }
    guard let type = MessageType(rawValue: typeString) else { throw CodingError.invalidType }

    let decoder = JSONDecoder()

    switch type {
    case .cancelSubscription:
        fatalError()
    case .command:
        fatalError()
    case .confirmSubscription:
        return try decoder.decode(ConfirmSubscriptionMessage.self, from: data)
    case .hibernateSubscription:
        fatalError()
    case .message:
        fatalError()
    case .ping:
        return try decoder.decode(PingMessage.self, from: data)
    case .rejectSubscription:
        return try decoder.decode(RejectSubscriptionMessage.self, from: data)
    case .welcome:
        return try decoder.decode(WelcomeMessage.self, from: data)
    }
}
func decodeIdentifier<Key>(in container: KeyedDecodingContainer<Key>, with key: Key) throws -> (original: Channel.Identifier, channelName: String, channelIdentifier: Channel.Identifier?) {
    let identifierString = try container.decode(String.self, forKey: key)
    let identifierData = identifierString.data(using: .utf8)!
    var identifier = try JSONSerialization.jsonObject(with: identifierData, options: []) as! Channel.Identifier

    let originalIdentifier = identifier

    guard let channelName = identifier.removeValue(forKey: "channel") else { throw CodingError.missingData }
    if identifier.count == 0 {
        return (originalIdentifier, channelName, nil)
    } else {
        return (originalIdentifier, channelName, identifier)
    }
}

// MARK: - Concrete Structs

public struct ConfirmSubscriptionMessage: Message {
    private enum CodingKeys: String, CodingKey {
        case type = "type"
        case identifier = "identifier"
    }

    public let kind: MessageType = .confirmSubscription
    private let originalIdentifier: Channel.Identifier

    public let channelName: String
    public let channelIdentifier: Channel.Identifier?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let ident = try decodeIdentifier(in: container, with: .identifier)

        self.originalIdentifier = ident.original
        self.channelName = ident.channelName
        self.channelIdentifier = ident.channelIdentifier
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.kind, forKey: .type)
        try container.encode(self.originalIdentifier, forKey: .identifier)
    }
}

public struct PingMessage: Message {
    private enum CodingKeys: String, CodingKey {
        case type = "type"
        case message = "message"
    }

    public let kind: MessageType = .ping
    public let message: Int

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.message = try container.decode(Int.self, forKey: .message)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.kind, forKey: .type)
        try container.encode(self.message, forKey: .message)
    }
}

public struct RejectSubscriptionMessage: Message {
    private enum CodingKeys: String, CodingKey {
        case type = "type"
        case identifier = "identifier"
    }

    public let kind: MessageType = .rejectSubscription
    private let originalIdentifier: Channel.Identifier

    public let channelName: String
    public let channelIdentifier: Channel.Identifier?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let ident = try decodeIdentifier(in: container, with: .identifier)

        self.originalIdentifier = ident.original
        self.channelName = ident.channelName
        self.channelIdentifier = ident.channelIdentifier
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.kind, forKey: .type)
        try container.encode(self.originalIdentifier, forKey: .identifier)
    }
}

public struct WelcomeMessage: Message {
    private enum CodingKeys: String, CodingKey {
        case type = "type"
    }

    public let kind: MessageType = .welcome

    public init(from decoder: Decoder) throws {}
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.kind, forKey: .type)
    }
}

