//
//  Agent.swift
//  AppleCLIKit
//
//  Created by Dominic Rodemer on 09/10/2026.
//  Copyright © 2026 Dominic Rodemer. All rights reserved.
//

import Darwin
import Foundation

/// A short-lived background process that holds the API key in memory, so a session needs one 1Password approval
/// instead of one per call. It is the only process that ever has the key; its `AgentServer` checks and signs every
/// request.
public struct Agent: Sendable {
    /// Used when `agent start` gets no `--ttl`.
    public static let defaultTTL: TimeInterval = 30 * 60
    private static let startupTimeout: TimeInterval = 10
    private static let startupPollInterval: TimeInterval = 0.1

    /// Handed to the background process through its stdin, never through arguments or the environment.
    private struct Startup<Credentials: Codable>: Codable {
        let credentials: Credentials
        let reference: String
        let expiresAt: Date
    }

    /// The tool's name, such as `asc`. It names the executable in messages.
    public let name: String
    /// Private to the user: it holds the socket.
    public let directory: URL

    /// An agent for the tool `name`, with its socket in `directory` (default: `~/Library/Caches/<name>`).
    public init(name: String, directory: URL? = nil) {
        self.name = name
        self.directory = directory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }

    // MARK: Public

    /// The socket the agent listens on.
    public var socketPath: String {
        self.directory.appendingPathComponent("agent.sock").path
    }

    /// Loads the key with `load` (one 1Password approval), starts the background process and returns its status.
    public func start(
        reference: String,
        ttl: TimeInterval,
        load: (String) async throws -> some Codable
    ) async throws
        -> String
    {
        if let status = try? self.send(AgentRequest(command: .status)) {
            throw CLIError.agent("already running; stop it first\n\(status.message ?? "")")
        }

        let credentials = try await load(reference)

        try self.createDirectory()
        unlink(self.socketPath)

        let startup = try JSONEncoder().encode(
            Startup(credentials: credentials, reference: reference, expiresAt: Date().addingTimeInterval(ttl))
        )
        let pid = try self.spawnServer(input: startup)

        for _ in 0..<Int(Self.startupTimeout / Self.startupPollInterval) {
            if let response = try? self.send(AgentRequest(command: .status)) {
                return response.message ?? ""
            }
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == pid {
                throw CLIError.agent("the agent exited during startup")
            }
            usleep(useconds_t(Self.startupPollInterval * 1_000_000))
        }
        kill(pid, SIGTERM)
        throw CLIError.agent("the agent didn't start within \(Int(Self.startupTimeout)) seconds")
    }

    /// Sends one request to the running agent.
    public func send(_ request: AgentRequest) throws -> AgentResponse {
        let fd: Int32
        do {
            fd = try UnixSocket.connect(to: self.socketPath)
        } catch {
            throw CLIError.agentNotRunning(tool: self.name)
        }
        defer { close(fd) }
        try UnixSocket.writeAll(fd, JSONEncoder().encode(request))
        shutdown(fd, SHUT_WR)
        let data = try UnixSocket.readAll(fd)
        do {
            return try JSONDecoder().decode(AgentResponse.self, from: data)
        } catch {
            throw CLIError.agent("invalid response from the agent")
        }
    }

    /// Entry point of the background process (`<name> agent serve`): reads the startup from stdin, serves requests
    /// with the server `makeServer` builds, and exits when the TTL ends.
    public func serve<Credentials: Codable>(
        _: Credentials.Type,
        makeServer: (Credentials) -> any AgentServer
    ) async throws {
        let startup = try JSONDecoder().decode(
            Startup<Credentials>.self,
            from: FileHandle.standardInput.readDataToEndOfFile()
        )
        signal(SIGHUP, SIG_IGN)
        signal(SIGPIPE, SIG_IGN)

        let listener = try UnixSocket.listen(at: self.socketPath)
        let server = makeServer(startup.credentials)
        let connection = AgentConnection(
            agent: self,
            server: server,
            reference: startup.reference,
            expiresAt: startup.expiresAt
        )

        let acceptThread = Thread {
            while true {
                let fd = accept(listener, nil, nil)
                guard fd >= 0 else {
                    continue
                }
                guard UnixSocket.isSameUser(fd) else {
                    close(fd)
                    continue
                }
                Task.detached {
                    await connection.handle(fd)
                }
            }
        }
        acceptThread.start()

        try? await Task.sleep(for: .seconds(max(0, startup.expiresAt.timeIntervalSinceNow)))
        self.shutDown()
    }

    /// Parses `--ttl` values like `90s`, `30m` or `2h`.
    public static func parseTTL(_ string: String) throws -> TimeInterval {
        let units: [Character: TimeInterval] = ["s": 1, "m": 60, "h": 3600]
        guard
            let unit = string.last.flatMap({ units[$0] }),
            let value = Int(string.dropLast()),
            value > 0 else
        {
            throw CLIError.usage("--ttl expects a duration like 90s, 30m or 2h, got '\(string)'")
        }
        return TimeInterval(value) * unit
    }

    /// Removes the socket and exits the background process.
    public func shutDown() -> Never {
        unlink(self.socketPath)
        exit(0)
    }

    // MARK: Private

    private func createDirectory() throws {
        let manager = FileManager.default
        try manager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: self.directory.path)
    }

    /// Spawns `<name> agent serve` in its own session, so it outlives the shell that started it.
    private func spawnServer(input: Data) throws -> pid_t {
        guard let executable = Bundle.main.executablePath else {
            throw CLIError.agent("can't locate the \(self.name) executable")
        }
        var pipeFDs: [Int32] = [0, 0]
        guard pipe(&pipeFDs) == 0 else {
            throw CLIError.agent("can't create a pipe")
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }
        posix_spawn_file_actions_adddup2(&fileActions, pipeFDs[0], 0)
        posix_spawn_file_actions_addopen(&fileActions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&fileActions, 2, "/dev/null", O_WRONLY, 0)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT))

        let strings: [String] = [executable, "agent", "serve"]
        let arguments: [UnsafeMutablePointer<CChar>?] = strings.map { $0.withCString { strdup($0) } } + [nil]
        defer { arguments.forEach { free($0) } }

        var pid: pid_t = 0
        let result = posix_spawn(&pid, executable, &fileActions, &attributes, arguments, environ)
        close(pipeFDs[0])
        guard result == 0 else {
            close(pipeFDs[1])
            throw CLIError.agent("can't start the agent: \(String(cString: strerror(result)))")
        }

        let writer = FileHandle(fileDescriptor: pipeFDs[1], closeOnDealloc: true)
        try writer.write(contentsOf: input)
        try writer.close()
        return pid
    }
}
