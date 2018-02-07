
import Starscream

public class Cable: WebSocketDelegate {

    private var socket: WebSocket

    public init(url: URL) {
        self.socket = WebSocket(url: url)
        self.socket.respondToPingWithPong = false
        self.socket.delegate = self
    }

    // Connection

    public var isConnected: Bool {
        return self.socket.isConnected
    }

    public func connect() {
        self.socket.connect()
    }

    public func disconnect() {
        self.socket.disconnect()
    }

    // Web Socket Delegate

    public func websocketDidConnect(socket: WebSocketClient) {
        print("socket connected")
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("socket disconnected")
        print(error)
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print(text)
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print(data)
    }
}
