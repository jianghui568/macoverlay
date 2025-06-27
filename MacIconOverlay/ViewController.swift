//
//  ViewController.swift
//  MacIconOverlay
//
//  Created by 一一 on 2025/6/15.
//

import Cocoa


class ViewController: NSViewController {
    @IBOutlet weak var pathField: NSTextField!
    @IBOutlet weak var syncedBtn: NSButton!
    @IBOutlet weak var syncingBtn: NSButton!
    
    private let userDefaults = UserDefaults(suiteName: "group.com.mycompany.MacIconOverlay")
    private let watchedPathsKey = "watchedPaths"
    private let lastUpdateTimeKey = "lastUpdateTime"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        FileUtils.runTests()
//        setupUI()
        
        do {
            let server = try UnixSocketServer(groupID: "group.com.mycompany.MacIconOverlay")
            server.start { message in
                print("8888888888 received : \(message)")
                if message == "paths" {
                    let paths = [
                        "/Users/player/projects/test",
                        "/Users/player/projects/sync",
                        "/Users/player/projects/snv"
                    ]
                    let encoder = JSONEncoder()
                    if let jsonData = try? encoder.encode(paths),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        print("8888888888 return  : \(jsonString)")
                        return jsonString
                    } else {
                        return "[]"
                    }
                } else {
                    // 尝试把 message 解码为 [String]
                    let decoder = JSONDecoder()
                    if let data = message.data(using: .utf8),
                       let arr = try? decoder.decode([String].self, from: data) {
                        
                        // 遍历解码得到的数组，构造[String:Int]字典，值为字符串长度的奇偶性（奇数为1，偶数为0）
                        var dic = [String: Int]()
                        for item in arr {
                            dic[item] = item.count % 2 == 1 ? 1 : 0
                        }
                        // 编码为json字符串返回
                        let encoder = JSONEncoder()
                        if let jsonData = try? encoder.encode(dic),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            print("8888888888 return  : \(jsonString)")
                            return jsonString
                        } else {
                            return "{}"
                        }
                    } else {
                        print("8888888888   decode error")
                        return "decode error"
                    }
                }
            }
        } catch {
            print("8888888888 启动服务器失败: \(error)")
        }
        
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
    
    func updateOverlay(state: String) {
        let path = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            showAlert(message: "请输入有效的路径")
            return
        }

    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: view.window!) { _ in }
    }
}

extension Notification.Name {
    static let iconOverlayStateChanged = Notification.Name("IconOverlayStateChanged")
}

