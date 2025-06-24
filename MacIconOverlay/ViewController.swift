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
    let socket = UnixSocket()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        
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
        
        socket.send(message: path)
        return;
        
        // 更新 NSUserDefaults 中的状态
        var watchedPaths = userDefaults?.dictionary(forKey: watchedPathsKey) as? [String: String] ?? [:]
        watchedPaths["path"] = path
        watchedPaths["state"] = state
        NSLog("88888888 watchedPaths : %@", watchedPaths)
        userDefaults?.set(watchedPaths, forKey: watchedPathsKey)
        
        // 更新时间戳
        userDefaults?.set(Date().timeIntervalSince1970, forKey: lastUpdateTimeKey)
        userDefaults?.synchronize()
        
        showAlert(message: "状态更新成功")
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

