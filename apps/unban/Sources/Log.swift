import Foundation
import Combine

final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var lines: [String] = []

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private let ioQueue = DispatchQueue(label: "unban.log.serial")

    func log(_ s: String) {
        let line = "[\(df.string(from: Date()))] \(s)"
        DispatchQueue.main.async {
            self.lines.append(line)
            if self.lines.count > 500 {
                self.lines.removeFirst(self.lines.count - 500)
            }
        }
        ioQueue.async { NSLog("%@", line) }
    }

    func clear() {
        DispatchQueue.main.async { self.lines.removeAll() }
    }

    var text: String { lines.joined(separator: "\n") }

    @discardableResult
    func export() -> String {
        let dir = "/var/mobile/Documents"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/wechat-unban-log.txt"
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }
}
