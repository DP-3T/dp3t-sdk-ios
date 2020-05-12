

import Foundation
@_exported import os.log

class Logger {
    #if CALIBRATION
    static weak var delegate: LoggingDelegate?
    #endif

    let osLog: OSLog
    let category: String

    init(_ bundle: Bundle = .main, category: String? = nil) {
        self.category = category ?? "default"
        osLog = OSLog(subsystem: bundle.bundleIdentifier ?? "default", category: category ?? "default")
    }

    init(_ aClass: AnyClass, category: String? = nil) {
        self.category = category ?? String(describing: aClass)
        osLog = OSLog(subsystem: Bundle(for: aClass).bundleIdentifier ?? "default", category: category ?? String(describing: aClass))
    }

    @inlinable func log(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .default, args)
    }

    @inlinable func info(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .info, args)
    }

    @inlinable func debug(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .debug, args)
    }

    @inlinable func error(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .error, args)
    }

    @inlinable func fault(_ message: StaticString, _ args: CVarArg...) {
        log(message, type: .fault, args)
    }

    func print(_ value: @autoclosure () -> Any) {
        guard osLog.isEnabled(type: .debug) else { return }
        os_log("%{public}@", log: osLog, type: .debug, String(describing: value()))
    }

    func dump(_ value: @autoclosure () -> Any) {
        guard osLog.isEnabled(type: .debug) else { return }
        var string = String()
        Swift.dump(value(), to: &string)
        os_log("%{public}@", log: osLog, type: .debug, string)
    }

    func trace(file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        guard osLog.isEnabled(type: .debug) else { return }
        let file = URL(fileURLWithPath: String(describing: file)).deletingPathExtension().lastPathComponent
        var function = String(describing: function)
        function.removeSubrange(function.firstIndex(of: "(")!...function.lastIndex(of: ")")!)
        os_log("%{public}@.%{public}@():%ld", log: osLog, type: .debug, file, function, line)
    }

    @usableFromInline internal func log(_ message: StaticString, type: OSLogType, _ a: [CVarArg]) {
        // The Swift overlay of os_log prevents from accepting an unbounded number of args
        // http://www.openradar.me/33203955

        if let delegate = Logger.delegate {
            let string = message.withUTF8Buffer {
                String(decoding: $0, as: UTF8.self)
            }
            delegate.log("[\(type.string)] [\(self.category)] \(String(format: string, arguments: a))")
        }
        assert(a.count <= 5)
        switch a.count {
        case 5: os_log(message, log: osLog, type: type, a[0], a[1], a[2], a[3], a[4])
        case 4: os_log(message, log: osLog, type: type, a[0], a[1], a[2], a[3])
        case 3: os_log(message, log: osLog, type: type, a[0], a[1], a[2])
        case 2: os_log(message, log: osLog, type: type, a[0], a[1])
        case 1: os_log(message, log: osLog, type: type, a[0])
        default: os_log(message, log: osLog, type: type)
        }
    }
}

fileprivate extension OSLogType {
    var string: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .default:
            return "DEFAULT"
        case .error:
            return "ERROR"
        case .fault:
            return "FAULT"
        case .info:
            return "INFO"
        default:
            return ""
        }
    }
}
