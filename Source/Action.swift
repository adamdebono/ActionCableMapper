
enum Command: String, Codable {
    case subscribe = "subscribe"
    case unsubscribe = "unsubscribe"
}

internal protocol Action {
    typealias Payload = [String: String]

    var payload: Payload { get }
}

internal struct SubscribeAction: Action {

    let payload: Action.Payload

    internal init(channel: Channel) {
        self.payload = [
            "command": Command.subscribe.rawValue,
            "identifier": channel.identifierPayload
        ]
    }
}

internal struct UnsubscribeAction: Action {

    let payload: Action.Payload

    internal init(channel: Channel) {
        self.payload = [
            "command": Command.unsubscribe.rawValue,
            "identifier": channel.identifierPayload
        ]
    }
}
