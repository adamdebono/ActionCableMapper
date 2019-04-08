
import Starscream

public class Cable: WebSocketDelegate {

    private var socket: WebSocket
    public var url: URL {
        return self.socket.currentURL
    }

    public weak var delegate: CableDelegate? = nil

    public convenience init(url: URL, reconnectionStrategy: RetryStrategy = .default) {
        let request = URLRequest(url: url)
        self.init(request: request, reconnectionStrategy: reconnectionStrategy)
    }

    public init(request: URLRequest, reconnectionStrategy: RetryStrategy = .default) {
        self.socket = WebSocket(request: request)
        self.reconnectionStrategy = reconnectionStrategy

        self.socket.respondToPingWithPong = false
        self.socket.delegate = self
    }

    // MARK: - Connection

    public var isConnected: Bool {
        return self.socket.isConnected
    }
    private var manuallyDisconnected: Bool = false
    private var shouldReconnect: Bool = false

    public let reconnectionStrategy: RetryStrategy
    private var retryHandler: RetryHandler?


    public func setConnectionRequest(header: String, value: String?) {
        self.socket.request.setValue(value, forHTTPHeaderField: header)
    }

    public func connect() {
        self.retryHandler = nil
        self.socket.connect()
    }

    public func disconnect() {
        self.shouldReconnect = false
        self.manuallyDisconnected = true
        self.socket.disconnect()
    }

    public func reconnect() {
        self.shouldReconnect = true
        self.manuallyDisconnected = true
        self.socket.disconnect()
    }

    private func retryConnect() {
        let retryHandler: RetryHandler
        if let handler = self.retryHandler {
            retryHandler = handler
        } else {
            retryHandler = RetryHandler(strategy: self.reconnectionStrategy)
            self.retryHandler = retryHandler
        }

        retryHandler.retry {
            self.socket.connect()
        }
    }

    // MARK: - Channel Subscription

    private var subscribedChannels: [Channel] = []
    private var pendingChannels: [Channel] = []
    private var waitingChannels: [Channel] = []

    internal func isSubscribed(to channel: Channel) -> Bool {
        return self.subscribedChannels.contains(where: { channel == $0 })
    }

    internal func subscribe(to channel: Channel) {
        guard !self.isSubscribed(to: channel) else { return }
        guard !self.pendingChannels.contains(where: { channel == $0 }) else { return }
        guard !self.waitingChannels.contains(where: { channel == $0 }) else { return }

        guard self.isConnected && !self.shouldReconnect else {
            self.waitingChannels.append(channel)
            return
        }

        let action = SubscribeAction(channel: channel)
        try? self.transmit(action)

        self.pendingChannels.append(channel)
    }

    internal func unsubscribe(from channel: Channel) {
        guard let index = self.subscribedChannels.firstIndex(where: { channel == $0 }) else { return }

        let action = UnsubscribeAction(channel: channel)
        try? self.transmit(action)

        self.subscribedChannels.remove(at: index)
    }


    private func subscribeWaitingChannels() {
        let channels = self.waitingChannels
        self.waitingChannels.removeAll()

        channels.forEach { (channel) in
            self.subscribe(to: channel)
        }
    }

    private func disconnectSubscribedChannels() {
        let subscribedChannels = self.subscribedChannels
        self.subscribedChannels.removeAll()
        self.waitingChannels.append(contentsOf: subscribedChannels)

        subscribedChannels.forEach { (channel) in
            channel.cableDisconnected()
        }
    }

    // MARK: - Sending Data

    private var waitingActions: [Action] = []

    internal func transmit(_ action: Action) throws {
        guard self.isConnected else { throw TransmitError.notConnected }

        let payload = try JSONEncoder().encodeString(action.payload)
        self.socket.write(string: payload)
    }

    internal func transmitWhenConnected(_ action: Action) {
        if self.isConnected && action.isReadyToSend && !self.shouldReconnect {
            try? self.transmit(action)
        } else {
            self.waitingActions.append(action)
        }
    }

    private func transmitWaitingActions() {
        guard self.isConnected else { return }

        var i = 0
        while i < self.waitingActions.count {
            let action = self.waitingActions[i]
            if action.isReadyToSend {
                self.waitingActions.remove(at: i)
                try? self.transmit(action)
            } else {
                i += 1
            }
        }
    }

    // MARK: - Web Socket Delegate

    public func websocketDidConnect(socket: WebSocketClient) {
        self.manuallyDisconnected = false
        self.shouldReconnect = false
        self.retryHandler = nil

        self.subscribeWaitingChannels()
        self.transmitWaitingActions()

        self.delegate?.cableDidConnect(cable: self)
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        self.disconnectSubscribedChannels()

        var attemptReconnect = true

        if let e = error, let error = e as? WSError {
            switch error.code {
            case 2, 404, 1000, 1002, 1003, 1007, 1008, 1009, 9847:
                // unknown domain, not found, closed, protocol violation x5, ssl handshake
                attemptReconnect = false
            case 61, 1005:
                // refused, unknown
                break
            default:
                break
            }
        }

        if self.shouldReconnect || (attemptReconnect && !self.manuallyDisconnected) {
            self.retryConnect()
        }

        self.delegate?.cableDidDisconnect(cable: self)
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        guard let message = try? decodeMessage(text) else { return }

        switch message.kind {
        case .welcome, .ping:
            break
        case .cancelSubscription:
            break
        case .command:
            break
        case .confirmSubscription:
            guard let message = message as? ConfirmSubscriptionMessage else { return }
            guard let index = self.pendingChannels.firstIndex(where: { $0 == (message.channelName, message.channelIdentifier) }) else { return }
            let channel = self.pendingChannels[index]
            self.pendingChannels.remove(at: index)
            self.subscribedChannels.append(channel)

            channel.subscriptionConfirmed(on: self)

            self.transmitWaitingActions()
        case .hibernateSubscription:
            break
        case .message:
            guard let message = message as? MessageMessage else { return }
            guard let channel = self.subscribedChannels.first(where: { $0 == (message.channelName, message.channelIdentifier) }) else { return }
            channel.received(message: message)
        case .rejectSubscription:
            guard let message = message as? RejectSubscriptionMessage else { return }
            guard let index = self.pendingChannels.firstIndex(where: { $0 == (message.channelName, message.channelIdentifier) }) else { return }
            let channel = self.pendingChannels[index]
            self.pendingChannels.remove(at: index)

            channel.subscriptionRejected(on: self)
        }
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {}
}

public protocol CableDelegate: AnyObject {
    func cableDidConnect(cable: Cable)
    func cableDidDisconnect(cable: Cable)
}
