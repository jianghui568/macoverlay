//
//  UnixSocketClient.swift
//  MacIconOverlay
//
//  Created by 一一 on 2025/6/29.
//

import Foundation
import Network

/// Unix Socket 客户端类
/// 用于连接到Unix域套接字服务器，发送消息并接收响应
class UnixSocketClient {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "UnixSocketClientQueue")
    private let groupID: String
    
    /// 初始化客户端
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
    
    /// 连接到服务器。此方法会阻塞，直到连接成功、失败或超时。
    /// - Parameter timeout: 连接超时时间
    /// - Returns: 连接是否成功
    func connect(timeout: TimeInterval = 3.0) -> Bool {
        // 如果连接已就绪，直接返回成功
        if let existingConnection = connection, existingConnection.state == .ready {
            return true
        }
        
        // 如果有旧的连接，先取消它
        if let existingConnection = connection {
            existingConnection.cancel()
        }

        guard let path = socketPath() else {
            print("❌ Could not resolve socket path")
            return false
        }
        
        let endpoint = NWEndpoint.unix(path: path)
        // 使用正确的 Unix Domain Socket 参数
        let params = NWParameters(tls: nil, tcp: .init())
        
        let newConnection = NWConnection(to: endpoint, using: params)
        self.connection = newConnection
        
        let semaphore = DispatchSemaphore(value: 0)
        
        newConnection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Connection is ready.")
                semaphore.signal()
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                self?.connection = nil
                semaphore.signal()
            case .cancelled:
                self?.connection = nil
                semaphore.signal()
            default:
                break
            }
        }
        
        print("🔗 Attempting to connect to: \(path)")
        newConnection.start(queue: queue)
        
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            print("❌ Connection timed out.")
            newConnection.cancel()
            self.connection = nil
            return false
        }
        
        // 再次检查最终状态
        let isConnected = newConnection.state == .ready
        if !isConnected {
            self.connection = nil
        }
        return isConnected
    }
    
    /// 同步发送消息并等待响应
    /// - Parameters:
    ///   - message: 要发送的消息
    ///   - timeout: 超时时间（秒）
    /// - Returns: 服务器响应，如果失败则返回nil
    func sendAndReceive(_ message: String, timeout: TimeInterval = 5.0) -> String? {
        guard let connection = connection, connection.state == .ready else {
            print("❌ Not connected. Call connect() first.")
            return nil
        }
        
        var sendError: Error?
        let sendSemaphore = DispatchSemaphore(value: 0)
        connection.send(content: message.data(using: .utf8), completion: .contentProcessed { error in
            sendError = error
            sendSemaphore.signal()
        })
        
        if sendSemaphore.wait(timeout: .now() + timeout) == .timedOut {
            print("❌ Send timed out for message: \(message)")
            return nil
        }
        
        if let error = sendError {
            print("❌ Send error: \(error)")
            return nil
        }
        
        var responseData: Data?
        var receiveError: Error?
        let receiveSemaphore = DispatchSemaphore(value: 0)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            responseData = data
            receiveError = error
            if isComplete {
                print("ℹ️ Connection closed by peer.")
            }
            receiveSemaphore.signal()
        }
        
        if receiveSemaphore.wait(timeout: .now() + timeout) == .timedOut {
            print("❌ Receive timed out for message: \(message)")
            return nil
        }
        
        if let error = receiveError {
            print("❌ Receive error: \(error)")
            return nil
        }
        
        guard let data = responseData, !data.isEmpty else {
            print("❌ No data received or empty response.")
            return nil
        }
        
        let response = String(data: data, encoding: .utf8)
        print("�� Received response: \(response ?? "nil")")
        return response
    }
    
    /// 断开连接
    func disconnect() {
        connection?.cancel()
        connection = nil
        print("🔌 Unix Socket Client disconnected")
    }
    
    /// 检查连接状态
    var isConnected: Bool {
        return connection?.state == .ready
    }
}

// MARK: - 便捷方法

extension UnixSocketClient {
    
    /// 发送ping请求
    /// - Returns: 是否收到pong响应
    func ping() -> Bool {
        let response = sendAndReceive("ping", timeout: 2.0)
        return response == "pong"
    }
    
    /// 获取监控路径列表
    /// - Returns: 路径数组，如果失败则返回空数组
    func getPaths() -> [String] {
        guard let response = sendAndReceive("paths", timeout: 3.0),
              let data = response.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return paths
    }
    
    /// 查询文件状态
    /// - Parameter path: 文件路径
    /// - Returns: 状态字符串
    func getStatus(for path: String) -> String {
        let response = sendAndReceive("status:\(path)", timeout: 3.0)
        return response ?? "unknown"
    }
    
    /// 更新文件状态
    /// - Parameters:
    ///   - path: 文件路径
    ///   - status: 新状态
    /// - Returns: 更新是否成功
    func updateStatus(path: String, status: String) -> Bool {
        let response = sendAndReceive("update:\(path):\(status)", timeout: 3.0)
        return response?.hasPrefix("updated:") == true
    }
}
