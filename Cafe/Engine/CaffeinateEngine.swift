import Darwin
import Foundation

/// Manages a `/usr/bin/caffeinate -dims` child process.
final class CaffeinateEngine: @unchecked Sendable {
    private var process: Process?
    private let lock = NSLock()

    /// Called when the process exits unexpectedly or finishes.
    var onProcessEnded: (@Sendable () -> Void)?

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning == true
    }

    @discardableResult
    func start(seconds: TimeInterval?) -> Bool {
        stop()

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")

        var args = ["-dims"]
        if let seconds, seconds > 0 {
            args.append(contentsOf: ["-t", String(Int(seconds.rounded()))])
        }
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        task.terminationHandler = { [weak self] proc in
            guard let self else { return }
            self.lock.lock()
            if self.process === proc {
                self.process = nil
            }
            self.lock.unlock()
            self.onProcessEnded?()
        }

        do {
            try task.run()
            lock.lock()
            process = task
            lock.unlock()
            return true
        } catch {
            return false
        }
    }

    func stop() {
        lock.lock()
        let task = process
        process = nil
        lock.unlock()

        guard let task else { return }
        if task.isRunning {
            task.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
                if task.isRunning {
                    kill(task.processIdentifier, SIGKILL)
                }
            }
        }
    }

    deinit {
        stop()
    }
}
