import Foundation

class Logger {
    static let shared = Logger()
    private let fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    
    private init() {
        // 获取扩展的容器目录
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mycompany.MacIconOverlay") else {
            NSLog("无法获取容器目录")
            fileHandle = nil
            dateFormatter = DateFormatter()
            return
        }
        
        // 创建日志目录
        let logDirectory = containerURL.appendingPathComponent("Logs")
        let logFile = logDirectory.appendingPathComponent("finder_sync.log")
        
        // 确保日志目录存在
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // 创建或打开日志文件
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }
        
        // 打开文件句柄
        fileHandle = try? FileHandle(forWritingTo: logFile)
        
        // 设置日期格式化器
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        // 将文件指针移到末尾
        fileHandle?.seekToEndOfFile()
        
        NSLog("日志文件路径: \(logFile.path)")
    }
    
    deinit {
        fileHandle?.closeFile()
    }
    
    func log(_ message: String, type: LogType = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(type.rawValue)] \(message)\n"
        
        // 输出到控制台
        NSLog("%@", logMessage)
        
        // 输出到文件
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
            fileHandle?.synchronizeFile()
        }
    }
    
    enum LogType: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
} 