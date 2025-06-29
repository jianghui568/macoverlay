import Foundation
import Network

/// Unix Socket 服务器类
/// 用于在应用组内创建Unix域套接字服务器，处理客户端连接和消息
class UnixSocketServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "UnixSocketServerQueue")
    private let groupID: String
    
    /// 消息处理器类型
    typealias MessageHandler = (String) -> String
    
    /// 初始化服务器
    /// - Parameter groupID: 应用组标识符
    init(groupID: String) {
        self.groupID = groupID
    }
    
    /// 获取socket路径
    /// - Returns: socket文件路径，如果获取失败则返回nil
    private func socketPath() -> String? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            return nil
        }
        return containerURL.appendingPathComponent("unix_socket.sock").path
    }
    
    /// 启动服务器
    /// - Parameter onReceive: 接收到消息时的回调处理函数，返回响应数据
    func startServer(onReceive: @escaping MessageHandler) {
        guard let path = socketPath() else {
            print("❌ Failed to get socket path")
            return
        }
        
        // 清理之前的socket文件
        unlink(path)
        
        let params = NWParameters(tls: nil, tcp: .init())
        
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = false
        params.requiredLocalEndpoint = NWEndpoint.unix(path: path)
        
        do {
            listener = try NWListener(using: params)
        } catch {
            print("❌ Failed to start listener: \(error)")
            return
        }
        
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self!.queue)
            self?.receive(on: connection, handler: onReceive)
        }
        
        listener?.start(queue: queue)
        print("✅ Unix Socket Server started at: \(path)")
    }
    
    /// 处理连接上的消息接收和响应
    /// - Parameters:
    ///   - connection: 网络连接
    ///   - handler: 消息处理回调，返回响应数据
    private func receive(on connection: NWConnection, handler: @escaping MessageHandler) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                print("📩 Received: \(message)")
                
                // 处理消息并获取响应
                let response = handler(message)
                print("📤 Sending response: \(response)")
                
                // 发送响应
                let responseData = response.data(using: .utf8) ?? Data()
                connection.send(content: responseData, completion: .contentProcessed { error in
                    if let error = error {
                        print("❌ Failed to send response: \(error)")
                    } else {
                        print("✅ Response sent successfully")
                    }
                })
            }
            
            if error == nil {
                self?.receive(on: connection, handler: handler) // 继续监听
            } else {
                print("❌ Receive error: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    /// 停止服务器
    func stopServer() {
        listener?.cancel()
        listener = nil
        print("🔴 Unix Socket Server stopped")
    }
    
    /// 检查服务器是否正在运行
    var isRunning: Bool {
        return listener != nil
    }
}

// MARK: - 预定义的消息处理器

extension UnixSocketServer {
    
    /// 创建默认的消息处理器
    /// - Returns: 消息处理函数
    static func createDefaultMessageHandler() -> MessageHandler {
        return { message in
            // 解析消息类型
            if message.hasPrefix("ping") {
                return "pong"
            } else if message.hasPrefix("paths") {
                // 返回监控的路径列表
                let paths = [
                    "/Users/test/documents",
                    "/Users/test/downloads",
                    "/Users/test/desktop"
                ]
                if let jsonData = try? JSONEncoder().encode(paths),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    return jsonString
                }
                return "[]"
            } else if message.hasPrefix("status:") {
                // 处理状态查询
                let path = String(message.dropFirst(7))
                return "status:\(path):synced"
            } else if message.hasPrefix("update:") {
                // 处理状态更新
                let components = message.components(separatedBy: ":")
                if components.count >= 3 {
                    let path = components[1]
                    let status = components[2]
                    return "updated:\(path):\(status)"
                }
                return "error:invalid_format"
            } else {
                // 默认回显
                return "echo:\(message)"
            }
        }
    }
} 
