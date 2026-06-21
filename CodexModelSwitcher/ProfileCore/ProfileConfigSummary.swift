import Foundation

public struct ProfileConfigSummary: Equatable {
    public var model: String?
    public var modelProvider: String?
    public var providerIDs: [String]

    public static func parse(_ content: String) -> ProfileConfigSummary {
        var model: String?
        var modelProvider: String?
        var providerIDs: [String] = []
        var isTopLevel = true

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            if trimmed.hasPrefix("[") {
                isTopLevel = false
                if let providerID = providerID(from: trimmed) {
                    providerIDs.append(providerID)
                }
                continue
            }
            if isTopLevel, trimmed.hasPrefix("model =") {
                model = quotedValue(from: trimmed)
            }
            if isTopLevel, trimmed.hasPrefix("model_provider =") {
                modelProvider = quotedValue(from: trimmed)
            }
        }

        return ProfileConfigSummary(model: model, modelProvider: modelProvider, providerIDs: providerIDs)
    }

    private static func quotedValue(from line: String) -> String? {
        guard let first = line.firstIndex(of: "\""),
              let last = line.lastIndex(of: "\""),
              first < last else {
            return nil
        }
        return String(line[line.index(after: first)..<last])
    }

    private static func providerID(from tableHeader: String) -> String? {
        guard tableHeader.hasPrefix("[model_providers."),
              tableHeader.hasSuffix("]") else {
            return nil
        }
        return String(tableHeader.dropFirst("[model_providers.".count).dropLast())
            .split(separator: ".", maxSplits: 1)
            .first
            .map(String.init)
    }
}
