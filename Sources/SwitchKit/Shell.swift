import Foundation

public struct CommandResult: Equatable {
    public let status: Int32
    public let output: String
    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
    public var ok: Bool { status == 0 }
}

/// Every system command goes through this, so switches are testable with a fake.
public protocol CommandRunner: AnyObject {
    @discardableResult
    func run(_ tool: String, _ args: [String]) -> CommandResult
}

public enum Tool {
    public static let defaults = "/usr/bin/defaults"
    public static let osascript = "/usr/bin/osascript"
    public static let killall = "/usr/bin/killall"
    public static let open = "/usr/bin/open"
    public static let pmset = "/usr/bin/pmset"
}

public final class ProcessRunner: CommandRunner {
    public init() {}

    public func run(_ tool: String, _ args: [String]) -> CommandResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return CommandResult(status: -1, output: "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let out = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return CommandResult(status: p.terminationStatus, output: out)
    }
}

public enum SwitchError: Error, LocalizedError, Equatable {
    case automationDenied(app: String)
    case failed(String)
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case .automationDenied(let app):
            return "Allow Switchboard to control \(app): System Settings → Privacy & Security → Automation."
        case .failed(let msg): return msg
        case .unavailable(let msg): return msg
        }
    }
}

extension CommandRunner {
    /// Runs AppleScript and maps the TCC "not authorized" code (-1743) to a readable error.
    func appleScript(_ source: String, target: String = "System Events") throws -> String {
        let r = run(Tool.osascript, ["-e", source])
        if r.ok { return r.output }
        if r.output.contains("-1743") || r.output.contains("-10004") || r.output.lowercased().contains("not authorized") {
            throw SwitchError.automationDenied(app: target)
        }
        throw SwitchError.failed(r.output.isEmpty ? "AppleScript failed (\(r.status))" : r.output)
    }

    func defaultsBool(_ domain: String, _ key: String) -> Bool? {
        let r = run(Tool.defaults, ["read", domain, key])
        guard r.ok else { return nil } // key missing
        switch r.output.lowercased() {
        case "1", "true", "yes": return true
        case "0", "false", "no": return false
        default: return nil
        }
    }
}
