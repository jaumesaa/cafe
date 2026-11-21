import Darwin
import Foundation

/// Manages a single `/usr/bin/caffeinate -dims` child process.
///
/// There is never more than one child: `start` stops the previous one first, `stop`
/// terminates it (SIGTERM, then SIGKILL if it lingers), and the child is told to watch
/// this app's pid (`-w`), so it exits by itself if Cafe crashes or is force-quit and can
/// never be left behind keeping the Mac awake.
final class CaffeinateEngine: @unchecked Sendable {
    private var process: Process?
    private let lock = NSLock()

    /// Called when the current process exits on its own (timed out or killed from
    /// outside) — not when `stop()` ended it.
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

        var args = ["-dims", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        if let seconds, seconds > 0 {
            args.append(contentsOf: ["-t", String(Int(seconds.rounded()))])
        }
        task.arguments = args
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        task.terminationHandler = { [weak self] proc in
            guard let self else { return }
            self.lock.lock()
            let wasCurrent = self.process === proc
            if wasCurrent {
                self.process = nil
            }
            self.lock.unlock()
            // A process that `stop()` already detached ended on purpose; only report
            // the one that ended by itself.
            if wasCurrent {
                self.onProcessEnded?()
            }
        }

        // Publish the task before it runs so a child that exits immediately is still
        // recognised as the current one by the termination handler.
        lock.lock()
        process = task
        lock.unlock()
        do {
            try task.run()
            return true
        } catch {
            lock.lock()
            if process === task {
                process = nil
            }
            lock.unlock()
            return false
        }
    }

    /// Ends the child and waits briefly for it, so a stop or a quit never leaves it
    /// running; one that ignores SIGTERM is killed.
    func stop() {
        lock.lock()
        let task = process
        process = nil
        lock.unlock()

        guard let task, task.isRunning else { return }
        let pid = task.processIdentifier
        task.terminate()
        // caffeinate exits on SIGTERM within a few ms; never block the UI for long.
        let deadline = Date().addingTimeInterval(0.3)
        while task.isRunning, Date() < deadline {
            usleep(5_000)
        }
        if task.isRunning {
            kill(pid, SIGKILL)
        }
    }

    deinit {
        stop()
    }
}
