//
//  ViewController.swift
//  MacIconOverlay
//
//  Created by 一一 on 2025/6/15.
//

import Cocoa
import Network

class ViewController: NSViewController {
    @IBOutlet weak var pathField: NSTextField!
    @IBOutlet weak var syncedBtn: NSButton!
    @IBOutlet weak var syncingBtn: NSButton!
    
    private let userDefaults = UserDefaults(suiteName: "group.com.mycompany.MacIconOverlay")
    private let watchedPathsKey = "watchedPaths"
    private let lastUpdateTimeKey = "lastUpdateTime"
    
    // 使用新的Unix Socket类
    private let server = UnixSocketServer(groupID: "group.com.mycompany.MacIconOverlay")
    private let client = UnixSocketClient(groupID: "group.com.mycompany.MacIconOverlay")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 启动Unix Socket服务器
        startUnixSocketServer()
        
        // 设置UI
        setupUI()
    }
    
    /// 启动Unix Socket服务器
    private func startUnixSocketServer() {
        // 使用自定义消息处理器
//        let messageHandler = UnixSocketServer.createCustomMessageHandler { [weak self] message in
//            return self?.handleServerMessage(message) ?? "error:unknown"
//        }
        
        server.startServer(onReceive: handleServerMessage)
    }
    
    /// 处理服务器接收到的消息
    /// - Parameter message: 接收到的消息
    /// - Returns: 响应消息
    private func handleServerMessage(_ message: String) -> String {
        print("🔄 Processing message: \(message)")
        
        // 根据消息类型返回不同的响应
        if message.hasPrefix("ping") {
            return "pong"
        } else if message.hasPrefix("paths") {
            // 返回监控的路径列表
            let paths = getWatchedPaths()
            if let jsonData = try? JSONEncoder().encode(paths),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
            return "[]"
        } else if message.hasPrefix("status:") {
            // 处理状态查询
            let path = String(message.dropFirst(7))
            let status = getFileStatus(for: path)
            return "status:\(path):\(status)"
        } else if message.hasPrefix("update:") {
            // 处理状态更新
            let components = message.components(separatedBy: ":")
            if components.count >= 3 {
                let path = components[1]
                let status = components[2]
                updateFileStatus(path: path, status: status)
                return "updated:\(path):\(status)"
            }
            return "error:invalid_format"
        } else if message.hasPrefix("add:") {
            // 添加监控路径
            let path = String(message.dropFirst(4))
            addWatchedPath(path)
            return "added:\(path)"
        } else if message.hasPrefix("remove:") {
            // 移除监控路径
            let path = String(message.dropFirst(7))
            removeWatchedPath(path)
            return "removed:\(path)"
        } else {
            // 默认回显
            return "echo:\(message)"
        }
    }
    
    /// 获取监控的路径列表
    /// - Returns: 路径数组
    private func getWatchedPaths() -> [String] {
        return userDefaults?.array(forKey: watchedPathsKey) as? [String] ?? []
    }
    
    /// 添加监控路径
    /// - Parameter path: 路径
    private func addWatchedPath(_ path: String) {
        var paths = getWatchedPaths()
        if !paths.contains(path) {
            paths.append(path)
            userDefaults?.set(paths, forKey: watchedPathsKey)
        }
    }
    
    /// 移除监控路径
    /// - Parameter path: 路径
    private func removeWatchedPath(_ path: String) {
        var paths = getWatchedPaths()
        paths.removeAll { $0 == path }
        userDefaults?.set(paths, forKey: watchedPathsKey)
    }
    
    /// 获取文件状态
    /// - Parameter path: 文件路径
    /// - Returns: 状态字符串
    private func getFileStatus(for path: String) -> String {
        // 这里可以从UserDefaults或其他存储中获取文件状态
        // 暂时返回默认状态
        return "synced"
    }
    
    /// 更新文件状态
    /// - Parameters:
    ///   - path: 文件路径
    ///   - status: 新状态
    private func updateFileStatus(path: String, status: String) {
        // 这里可以将文件状态保存到UserDefaults或其他存储中
        let key = "status_\(path)"
        userDefaults?.set(status, forKey: key)
        userDefaults?.set(Date(), forKey: lastUpdateTimeKey)
    }
    
    private func setupUI() {
        // 设置按钮标题和图标
        syncedBtn.title = "已同步"
        syncingBtn.title = "同步中"
        
        // 设置按钮图标
        if let syncedImage = NSImage(named: "synced") {
            syncedBtn.image = syncedImage
            syncedBtn.imagePosition = .imageLeft
        }
        
        if let syncingImage = NSImage(named: "syncing") {
            syncingBtn.image = syncingImage
            syncingBtn.imagePosition = .imageLeft
        }
        
        // 设置文本框占位符
        pathField.placeholderString = "请输入文件或文件夹路径"
    }
    
    @IBAction func setSynced(_ sender: Any) {
        updateOverlay(state: "synced")
    }
    
    @IBAction func setSyncing(_ sender: Any) {
        updateOverlay(state: "syncing")
    }
    
    /// 更新图标覆盖状态
    /// - Parameter state: 状态字符串
    func updateOverlay(state: String) {
        let path = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            showAlert(message: "请输入有效的路径")
            return
        }

        // 使用新的同步请求-响应功能
        if client.connect() {
            let success = client.updateStatus(path: path, status: state)
            if success {
                print("✅ Status updated successfully: \(path) -> \(state)")
                showAlert(message: "状态更新成功")
            } else {
                print("❌ Failed to update status")
                showAlert(message: "状态更新失败")
            }
        } else {
            print("❌ Failed to connect to server")
            showAlert(message: "连接服务器失败")
        }
    }
    
    /// 测试连接
    @IBAction func testConnection(_ sender: Any) {
        if client.connect() {
            let isAlive = client.ping()
            if isAlive {
                showAlert(message: "连接测试成功")
            } else {
                showAlert(message: "连接测试失败")
            }
        } else {
            showAlert(message: "无法连接到服务器")
        }
    }
    
    /// 获取监控路径
    @IBAction func getPaths(_ sender: Any) {
        if client.connect() {
            let paths = client.getPaths()
            let pathsText = paths.joined(separator: "\n")
            showAlert(message: "监控路径:\n\(pathsText)")
        } else {
            showAlert(message: "无法连接到服务器")
        }
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: view.window!) { _ in }
    }
    
    deinit {
        // 清理资源
        server.stopServer()
        client.disconnect()
    }
}

extension Notification.Name {
    static let iconOverlayStateChanged = Notification.Name("IconOverlayStateChanged")
}

