//
//  ProcessRunner.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Foundation

/// Runs a system tool and collects its output.
public enum ProcessRunner {
    /// The outcome of a finished (or timed-out and terminated) process.
    public struct Result {
        /// The exit status.
        public let status: Int32
        /// Everything the process wrote to stdout.
        public let stdout: Data
        /// Everything the process wrote to stderr.
        public let stderr: Data
        /// Whether the process was terminated because it ran past the timeout.
        public let isTimedOut: Bool

        /// `nil` on success, otherwise why the process failed.
        public var failureMessage: String? {
            if self.isTimedOut {
                return "timed out"
            }
            guard self.status != 0 else {
                return nil
            }
            return String(decoding: self.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Runs the executable, feeding `input` to its stdin, and terminates it after `timeout` seconds.
    public static func run(
        _ executableURL: URL,
        arguments: [String],
        input: Data? = nil,
        timeout: TimeInterval
    ) throws
        -> Result
    {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdout = PipeCollector()
        let stderr = PipeCollector()
        let stdinPipe = Pipe()
        process.standardOutput = stdout.pipe
        process.standardError = stderr.pipe
        process.standardInput = input == nil ? FileHandle.nullDevice : stdinPipe

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }

        try process.run()

        if let input {
            DispatchQueue.global().async {
                try? stdinPipe.fileHandleForWriting.write(contentsOf: input)
                try? stdinPipe.fileHandleForWriting.close()
            }
        }

        let isTimedOut = exited.wait(timeout: .now() + timeout) == .timedOut
        if isTimedOut {
            process.terminate()
            exited.wait()
        }

        return Result(
            status: process.terminationStatus,
            stdout: stdout.finish(),
            stderr: stderr.finish(),
            isTimedOut: isTimedOut
        )
    }
}
