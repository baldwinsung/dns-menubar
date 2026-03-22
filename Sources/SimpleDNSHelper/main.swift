import Darwin
import Foundation

let socketPath = "/var/run/simpledns.sock"

// Remove stale socket if it exists
unlink(socketPath)

let serverFd = socket(AF_UNIX, SOCK_STREAM, 0)
guard serverFd >= 0 else {
    fputs("Failed to create socket\n", stderr)
    exit(1)
}

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
socketPath.withCString { ptr in
    withUnsafeMutablePointer(to: &addr.sun_path) {
        $0.withMemoryRebound(to: CChar.self, capacity: 104) {
            _ = strlcpy($0, ptr, 104)
        }
    }
}

let bindResult = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(serverFd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
}
guard bindResult == 0 else {
    fputs("Failed to bind socket: \(String(cString: strerror(errno)))\n", stderr)
    exit(1)
}

chmod(socketPath, 0o666)

guard listen(serverFd, 5) == 0 else {
    fputs("Failed to listen on socket\n", stderr)
    exit(1)
}

func jsonResponse(ok: Bool, error: String? = nil) -> Data {
    var dict: [String: Any] = ["ok": ok]
    if let error = error { dict["error"] = error }
    return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data("{\"ok\":false}".utf8)
}

func handleClient(_ clientFd: Int32) {
    defer { close(clientFd) }

    var requestData = Data()
    var buf = [UInt8](repeating: 0, count: 4096)
    while true {
        let n = recv(clientFd, &buf, buf.count, 0)
        if n <= 0 { break }
        requestData.append(contentsOf: buf[0..<n])
        // Stop reading once we have a complete JSON object (ends with newline or buffer done)
        if buf[n - 1] == UInt8(ascii: "\n") || n < buf.count { break }
    }

    guard !requestData.isEmpty,
          let json = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any],
          let args = json["args"] as? [String],
          !args.isEmpty,
          args[0] == "-setdnsservers"
    else {
        let resp = jsonResponse(ok: false, error: "Invalid request")
        _ = resp.withUnsafeBytes { send(clientFd, $0.baseAddress!, resp.count, 0) }
        return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
    process.arguments = args

    let pipe = Pipe()
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        let resp = jsonResponse(ok: false, error: "Failed to run networksetup: \(error)")
        _ = resp.withUnsafeBytes { send(clientFd, $0.baseAddress!, resp.count, 0) }
        return
    }

    if process.terminationStatus == 0 {
        let resp = jsonResponse(ok: true)
        _ = resp.withUnsafeBytes { send(clientFd, $0.baseAddress!, resp.count, 0) }
    } else {
        let errOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let resp = jsonResponse(ok: false, error: "networksetup exited \(process.terminationStatus): \(errOutput)")
        _ = resp.withUnsafeBytes { send(clientFd, $0.baseAddress!, resp.count, 0) }
    }
}

// Accept loop
while true {
    let clientFd = accept(serverFd, nil, nil)
    if clientFd < 0 { continue }
    handleClient(clientFd)
}
