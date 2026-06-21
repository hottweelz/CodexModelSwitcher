import Foundation

public struct ProfileConfigEditor {
    public init() {}

    public func rewrite(_ content: String, selectedModel: String, selectedProvider: String?) -> String {
        var lines = content.components(separatedBy: .newlines)
        if lines.last == "" {
            lines.removeLast()
        }
        lines = removeTopLevelKey("model", from: lines)
        lines = removeTopLevelKey("model_provider", from: lines)

        var prefix = [#"model = "\#(tomlEscape(selectedModel))""#]
        if let selectedProvider, !selectedProvider.isEmpty, selectedProvider != "openai" {
            prefix.append(#"model_provider = "\#(tomlEscape(selectedProvider))""#)
        }

        let remaining = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        var output = prefix.joined(separator: "\n")
        if !remaining.isEmpty {
            output += "\n\n" + remaining
        }
        return output + "\n"
    }

    private func removeTopLevelKey(_ key: String, from lines: [String]) -> [String] {
        var isTopLevel = true
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") {
                isTopLevel = false
            }
            return !(isTopLevel && trimmed.hasPrefix("\(key) ="))
        }
    }

    private func tomlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
