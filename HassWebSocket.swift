import Foundation
import Starscream
import Combine

public class HassWebSocket: WebSocketDelegate {
    weak var delegate: HassWebSocketDelegate?
    public static let shared = HassWebSocket()

    @Published public var connectionState: HassFramework.ConnectionState = .disconnected
    private var socket: WebSocket!
    private let pingInterval: TimeInterval = 60.0
    public var messageId: Int = 0

    private var isAuthenticating = false
    public var isAuthenticated = false
    var pingTimer: Timer?
    private var reconnectionInterval: TimeInterval = 5.0
    private var isAttemptingReconnect = false
    private var messageQueue: [String] = []

    public init() {
        self.messageId = 0
        guard let requestURLString = getServerURLFromSecrets(),
              let requestURL = URL(string: requestURLString) else {
            fatalError("Failed to create a URL from the string provided in Secrets.plist or the URL is malformed.")
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = 5
        self.socket = WebSocket(request: request)
        self.socket.delegate = self
    }

    public func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        print("HassWebSocket received event: \(event)")

        switch event {
        case .connected(_):
            connectionState = .connected
            startHeartbeat()
            authenticate()

        case .disconnected:
            connectionState = .disconnected
            stopHeartbeat()
            delegate?.websocketDidDisconnect()

        case .text(let text):
            handleIncomingText(text)

        default:
            print("Received unhandled event: \(event)")
        }
    }

    private func handleIncomingText(_ text: String) {
        // Logic to handle incoming text messages
    }

    public func connect(completion: @escaping (Bool) -> Void) {
        connectionState = .connecting
        socket.connect()
    }

    public func disconnect() {
        isAuthenticating = false
        socket.disconnect()
        isAttemptingReconnect = false
        stopHeartbeat()
    }

    func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        guard let accessToken = getAccessToken() else {
            print("Access token not found, cannot authenticate")
            return
        }

        let authMessage = [
            "type": "auth",
            "access_token": accessToken
        ]

        if let data = try? JSONSerialization.data(withJSONObject: authMessage, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            socket.write(string: jsonString)
        }
    }

    private func getAccessToken() -> String? {
            guard let path = Bundle(for: type(of: self)).path(forResource: "Secrets", ofType: "plist"),
                  let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
                  let token = dict["HomeAssistantAccessToken"] as? String else {
                print("Failed to retrieve access token from Secrets.plist.")
                return nil
            }
            
            print("Access token retrieved: \(token)")
            return token
        }
        
        private func getServerURLFromSecrets() -> String? {
             // Logic to retrieve server URL from secrets
             return "Your_Server_URL"
         }

    private func startHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.socket.write(ping: Data())
        }
    }

    private func stopHeartbeat() {
        pingTimer?.invalidate()
    }
}
