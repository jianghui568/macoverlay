import Foundation
import Network

/// 简单的 Unix 域套接字服务器，支持异步接收和回复消息
class UnixSocketServer {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "UnixSocketServerQueue")

    /// 初始化监听指定 socket 路径
    init(groupID: String) throws {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)!
        let path = containerURL.appendingPathComponent("unix_socket.sock").path
        // Clean up previous socket file if it exists
        unlink(path)

        let params = NWParameters()
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = false
        params.requiredLocalEndpoint = NWEndpoint.unix(path: path)

        listener = try NWListener(using: params)
    }

    /// 启动服务器，收到消息后回调处理
    func start(onReceive: @escaping (String) -> String) {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection, onReceive: onReceive)
        }
        listener.start(queue: queue)
        print("🟢 UnixSocketServer started")
    }

    /// 停止服务器
    func stop() {
        listener.cancel()
        print("🔴 UnixSocketServer stopped")
    }

    /// 处理每个客户端连接
    private func handleConnection(_ connection: NWConnection, onReceive: @escaping (String) -> String) {
        connection.start(queue: queue)
        receiveNext(on: connection, onReceive: onReceive)
    }

    /// 持续接收消息
    private func receiveNext(on connection: NWConnection, onReceive: @escaping (String) -> String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
            if let data = data, !data.isEmpty, error == nil {
                let message = String(decoding: data, as: UTF8.self)
                let response = onReceive(message)
                connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in })
                // 继续接收下一条消息
                self.receiveNext(on: connection, onReceive: onReceive)
            } else {
                connection.cancel()
            }
        }
    }
} 
