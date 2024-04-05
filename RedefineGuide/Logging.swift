import Foundation
import os.log

enum LogLevel: Int {
    case trace = 0
    case debug
    case info
    case important
    case warning
    case error
}

extension LogLevel {
    func toString() -> String {
        switch (self) {
        case .trace:
            return "trace"
        case .debug:
            return "debug"
        case .info:
            return "info"
        case .important:
            return "IMPORTANT"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        }
    }
}

func currentLogLevel() -> LogLevel {
    #if DEBUG
    // App is running in debug mode, check if it's being debugged by Xcode
    if isDebuggerAttached() {
        return .trace // Or any other level you prefer for Xcode debugging
    } else {
        return .info // Or any other level for running in debug mode without Xcode
    }
    #else
    return .important // Or any other level for production/release builds
    #endif
}

func isDebuggerAttached() -> Bool {
    // Check if the app is being debugged by Xcode
    var info = kinfo_proc()
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    var size = MemoryLayout<kinfo_proc>.size
    let sysctlResult = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)

    return sysctlResult == 0 && (info.kp_proc.p_flag & P_TRACED) != 0
}

/// The logger used by the inner-workings of the app.  This is mostly a wrapper around os.log.Logger, but it also uses SwiftData to store all the important log entries (>= Info)
class RedefineLogger {
    private let logger: Logger
    let logLevel: LogLevel = currentLogLevel()
    let name: String
    private let saveData: Bool

    init(_ name: String) {
        saveData = RedefineLogger.logFileHandle != nil
        logger = Logger(subsystem: getDomain(), category: name)
        self.name = name
    }
    
    func shouldLog(_ level: LogLevel) -> Bool {
        return logLevel.rawValue <= level.rawValue
    }
    
    /// Creates a LogEntry and stores it in the database if the database is available.
    func saveEntry(level: LogLevel, levelName: String, message: String) -> String {
        // if there is no context, you can't create an instance of LogEntry without a system error that crashes the app
        guard saveData else {
            return message
        }
        
        let entry = LogEntry(time: Date(), level: LogLevel.info.rawValue, levelName: level.toString(), logger: self.name, message: message)
        RedefineLogger.entrySaver.add(entry)
        return message
    }

    func trace(_ message: @autoclosure () -> String) {
        guard shouldLog(.trace) else {
            return
        }
        let msg = message()
        logger.trace("\(msg, privacy: .private)")
    }
    
    func debug(_ message: @autoclosure () -> String) {
        guard shouldLog(.debug) else {
            return
        }
        let msg = message()
        logger.debug("\(msg, privacy: .private)")
    }
    
    func info(_ message: @autoclosure () -> String) {
        let level = LogLevel.info
        guard shouldLog(level) else {
            return
        }
        let message = saveEntry(level: level, levelName: "info", message: message())
        logger.info("\(message, privacy: .public)")
    }
    
    func important(_ message: @autoclosure () -> String) {
        let level = LogLevel.important
        guard shouldLog(level) else {
            return
        }
        let message = saveEntry(level: level, levelName: "important", message: message())
        logger.info("\(message, privacy: .public)")
    }
    
    func warning(_ message: @autoclosure () -> String) {
        let level = LogLevel.warning
        guard shouldLog(level) else {
            return
        }
        let message = saveEntry(level: level, levelName: "warning", message: message())
        logger.warning("\(message, privacy: .public)")
    }
    
    func error(_ message: @autoclosure () -> String) {
        let level = LogLevel.error
        guard shouldLog(level) else {
            return
        }
        let message = saveEntry(level: level, levelName: "error", message: message())
        logger.error("\(message, privacy: .public)")
    }
    
    func logAndGetError(_ message: String) -> Error {
        self.error(message)
        return getError(message)
    }
}

/// Contains static methods used for saving and loading log entries.
extension RedefineLogger {

    private static func getLogsPath() throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw getError("Could not get documents directory")
        }
        
        // put logs for each month in a separate directory
        let logsDirFormatter = DateFormatter()
        logsDirFormatter.dateFormat = "yyyy-MM"
        let logsDirName = "logs-\(logsDirFormatter.string(from: Date()))"

        let directory = documentsDirectory.appendingPathComponent(logsDirName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        
        let filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyy-MM-dd-HH"
        let fileName = "\(filenameFormatter.string(from: Date())).txt"
        
        let path = directory.appendingPathComponent(fileName, isDirectory: false)
        
        print("Saving logs to \(path.absoluteString)")
        return path
    }

    /// Current handle to the file that logs are writing to
    private static var logFileHandle: FileHandle? {
        // almost all the time
        if _logFileHandleResolved {
            return _logFileHandle
        }
        
        // protect against multiple threads entering this path and creating multiple file handles
        return logFileQueue.sync {
            if _logFileHandleResolved {
                return _logFileHandle
            }

            guard !isPreviewMode() else {
                _logFileHandleResolved = true
                return _logFileHandle
            }
            
            do {
                let path = try getLogsPath()
                // Ensure the file exists before trying to open it
                if !FileManager.default.fileExists(atPath: path.path) {
                    FileManager.default.createFile(atPath: path.path, contents: nil, attributes: nil)
                }
                _logFileHandle = try FileHandle(forWritingTo: path)
                _logFileHandle?.seekToEndOfFile() // Move to the end of the file
                
                registerLogFileHandleCloseOnBackground()
            } catch {
                print("Error re-opening log FileHandle: \(error.localizedDescription)")
            }
            _logFileHandleResolved = true // put it here to avoid flooding with error messages in case there was a problem

            return _logFileHandle
        }
        
    }
    private static var _logFileHandle: FileHandle?
    private static var _logFileHandleResolved: Bool = false
    private static let logFileQueue = DispatchQueue(label: "com.redefinecapture.logFileAccessQueue")

    private static func registerLogFileHandleCloseOnBackground() {
        guard !_registeredLogFileHandleClose else {
            return
        }
        LifecycleEventMonitor.shared.registerWillEnterBackgroundCallback {
            closeLogFileHandle()
        }
        _registeredLogFileHandleClose = true
    }
    private static var _registeredLogFileHandleClose: Bool = false

    /// Called when app is backgrounded to flush and close the file
    private static func closeLogFileHandle() {
        print("Closing log file due to app backgrounding")
        do {
            try logFileHandle?.close()
        } catch {
            print("Error closing log FileHandle: \(error.localizedDescription)")
        }
        _logFileHandleResolved = false
        _logFileHandle = nil // Ensure the handle is nil after closing
    }
    
    static func writeLogEntry(_ entry: LogEntry) {
        guard !isPreviewMode() else {
            return
        }
        guard let fileHandle = logFileHandle else {
            return
        }
        
        let formattedDate = entryTimeFormatter.string(from: entry.time)
        let formattedEntry = "[\(formattedDate)] [\(entry.levelName)] [\(entry.logger)] \(entry.message)\n"
        guard let entryData = formattedEntry.data(using: .utf8) else {
            print("Could not get log message data!")
            return
        }
        fileHandle.write(entryData)
    }

    private static var entryTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd hh:mm:ss a"
        return formatter
    }()

    /// Handles the saving of LogEntry objects.  Ensures that items from multiple threads won't create concurrency problems
    static var entrySaver: AsyncQueueProcessor<LogEntry> = {
        // in the future, you could experiment with increasing maxSize.  A bigger size could increase performance due to fewer save()
        // calls, but if a message was added and not saved before the app exited, you'll have lost data
        let processor = AsyncQueueProcessor<LogEntry>(signpostName: "LogEntries", maxSize: 1, processItems: { items in
            for entry in items {
                writeLogEntry(entry)
            }
        })
        processor.start()
        return processor
    }()
}


struct LogEntry {
    let time: Date
    let level: Int
    let levelName: String
    let logger: String
    let message: String

    init(time: Date, level: Int, levelName: String, logger: String, message: String) {
        self.time = time
        self.level = level
        self.levelName = levelName
        self.logger = logger
        self.message = message
    }
}

func getDomain() -> String {
    return Bundle.main.bundleIdentifier ?? "missing.bundle"
}

func getError(_ message: String) -> Error {
    return NSError(domain: getDomain(), code: 1000, userInfo: [NSLocalizedDescriptionKey: message])
}
