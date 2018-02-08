
import Starscream

public class Cable: WebSocketDelegate {

    private var socket: WebSocket
    public var url: URL {
        return self.socket.currentURL
    }

    public init(url: URL) {
        self.socket = WebSocket(url: url)
        self.socket.respondToPingWithPong = false
        self.socket.delegate = self
    }

    // MARK: - Connection

    public var isConnected: Bool {
        return self.socket.isConnected
    }

    public func connect() {
        self.socket.connect()
    }

    public func disconnect() {
        self.socket.disconnect()
    }

    // MARK: - Channel Subscription

    private var subscribedChannels: [Channel] = []
    private var pendingChannels: [Channel] = []
    private var waitingChannels: [Channel] = []

    internal func subscribe(to channel: Channel) {
        guard !self.subscribedChannels.contains(where: { channel == $0 }) else { return }
        guard !self.pendingChannels.contains(where: { channel == $0 }) else { return }
        guard !self.waitingChannels.contains(where: { channel == $0 }) else { return }

        guard self.isConnected else {
            self.waitingChannels.append(channel)
            return
        }

        let action = SubscribeAction(channel: channel)
        try? self.transmit(action)

        self.pendingChannels.append(channel)
    }

    private func subscribeWaitingChannels() {
        let channels = self.waitingChannels
        self.waitingChannels.removeAll()

        channels.forEach { (channel) in
            self.subscribe(to: channel)
        }
    }

    internal func unsubscribe(from channel: Channel) {
        guard let index = self.subscribedChannels.index(where: { channel == $0 }) else { return }

        let action = UnsubscribeAction(channel: channel)
        try? self.transmit(action)

        self.subscribedChannels.remove(at: index)
    }

    // MARK: - Sending Data

    internal func transmit(_ action: Action) throws {
        guard self.isConnected else { throw TransmitError.notConnected }

        let payload = try JSONEncoder().encodeString(action.payload)
        print(payload)
        self.socket.write(string: payload)
    }

    // MARK: - Web Socket Delegate

    public func websocketDidConnect(socket: WebSocketClient) {
        self.subscribeWaitingChannels()
        print("socket connected")
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("socket disconnected")
        print(error)
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print(text)

        guard let message = try? decodeMessage(text) else { return }
        print(message)

        switch message.kind {
        case .welcome, .ping:
            break
        case .cancelSubscription:
            break
        case .command:
            break
        case .confirmSubscription:
            guard let message = message as? ConfirmSubscriptionMessage else { return }
            guard let index = self.pendingChannels.index(where: { $0 == (message.channelName, message.channelIdentifier) }) else { return }
            let channel = self.pendingChannels[index]
            self.pendingChannels.remove(at: index)
            self.subscribedChannels.append(channel)

            channel.subscriptionConfirmed(on: self)
        case .hibernateSubscription:
            break
        case .message:
            break
        case .rejectSubscription:
            guard let message = message as? RejectSubscriptionMessage else { return }
            guard let index = self.pendingChannels.index(where: { $0 == (message.channelName, message.channelIdentifier) }) else { return }
            let channel = self.pendingChannels[index]
            self.pendingChannels.remove(at: index)

            channel.subscriptionRejected(on: self)
        }
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print(data)
    }
}
