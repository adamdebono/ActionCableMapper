
enum Command: String, Codable {
    case message = "message"
    case subscribe = "subscribe"
    case unsubscribe = "unsubscribe"
}

internal protocol Action {
    typealias Payload = [String: String]
    typealias DataPayload = [String: Any]

    var payload: Payload { get }

    var isReadyToSend: Bool { get }
}

internal struct MessageAction: Action {

    let payload: Action.Payload
    let channel: Channel

    var isReadyToSend: Bool {
        return channel.isConnected
    }

    internal init(channel: Channel, action: String, data: DataPayload) throws {
        var data = data
        data["action"] = action

        let dataData = try JSONSerialization.data(withJSONObject: data, options: [])
        guard let dataString = String(data: dataData, encoding: .utf8) else { throw CodingError.invalidType }

        self.channel = channel

        self.payload = [
            "command": Command.message.rawValue,
            "identifier": channel.identifierPayload,
            "data": dataString
        ]
    }
}

internal struct SubscribeAction: Action {

    let payload: Action.Payload
    let isReadyToSend = true

    internal init(channel: Channel) {
        self.payload = [
            "command": Command.subscribe.rawValue,
            "identifier": channel.identifierPayload
        ]
    }
}

internal struct UnsubscribeAction: Action {

    let payload: Action.Payload
    let isReadyToSend = true

    internal init(channel: Channel) {
        self.payload = [
            "command": Command.unsubscribe.rawValue,
            "identifier": channel.identifierPayload
        ]
    }
}
