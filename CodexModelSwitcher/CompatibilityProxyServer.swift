import Foundation
import Network

final class CompatibilityProxyServer {
    static let port: UInt16 = 48117
    static let address = "127.0.0.1:48117"

    var onStatusChange: ((ProxyServerStatus) -> Void)?

    private let queue = DispatchQueue(label: "codex-model-switcher.compatibility-proxy")
    private var listener: NWListener?
    private var services: [String: CodexService] = [:]

    func updateService(_ service: CodexService?) {
        let proxiedServices: [String: CodexService]
        if let service, service.useCompatibilityProxy, service.id != "openai" {
            proxiedServices = [service.id: service]
        } else {
            proxiedServices = [:]
        }

        queue.async {
            self.services = proxiedServices
            proxiedServices.isEmpty ? self.stop(status: .notRunning) : self.startIfNeeded()
        }
    }

    private func startIfNeeded() {
        guard listener == nil else { return }

        do {
            reportStatus(.starting)
            let port = NWEndpoint.Port(rawValue: Self.port)!
            let listener = try NWListener(using: .tcp, on: port)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.reportStatus(.active)
                case .failed:
                    self?.stop(status: .error)
                default:
                    break
                }
            }
            self.listener = listener
            listener.start(queue: queue)
        } catch {
            listener = nil
            reportStatus(.error)
        }
    }

    private func stop(status: ProxyServerStatus) {
        listener?.cancel()
        listener = nil
        reportStatus(status)
    }

    private func reportStatus(_ status: ProxyServerStatus) {
        onStatusChange?(status)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] chunk, _, _, error in
            guard let self else { return }
            guard error == nil, let chunk, !chunk.isEmpty else {
                connection.cancel()
                return
            }

            var nextBuffer = buffer
            nextBuffer.append(chunk)

            if let request = HTTPRequest(data: nextBuffer) {
                Task {
                    let response = await self.response(for: request)
                    self.send(response, on: connection)
                }
            } else {
                self.receiveRequest(on: connection, buffer: nextBuffer)
            }
        }
    }

    private func response(for request: HTTPRequest) async -> HTTPResponse {
        if request.method == "GET", request.path == "/health" {
            return .json([
                "status": "ok",
                "providers": Array(services.keys).sorted()
            ])
        }

        guard request.method == "POST" else {
            return .text(status: 405, body: "Method not allowed")
        }

        guard let serviceID = request.pathComponents.first,
              let service = services[serviceID] else {
            return .text(status: 404, body: "Unknown proxy provider")
        }

        guard let chatBody = chatCompletionsBody(from: request.body),
              let upstreamURL = chatCompletionsURL(for: service) else {
            return .text(status: 400, body: "Invalid Responses request")
        }

        do {
            var upstreamRequest = URLRequest(url: upstreamURL)
            upstreamRequest.httpMethod = "POST"
            upstreamRequest.timeoutInterval = 120
            upstreamRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !service.apiKey.isEmpty {
                upstreamRequest.setValue("Bearer \(service.apiKey)", forHTTPHeaderField: "Authorization")
            }
            upstreamRequest.httpBody = try JSONSerialization.data(withJSONObject: chatBody)

            let (data, response) = try await URLSession.shared.data(for: upstreamRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 502
            guard (200..<300).contains(status) else {
                return HTTPResponse(status: status, headers: jsonHeaders, body: data)
            }

            guard let responseBody = responsesBody(fromChatCompletionsData: data) else {
                return HTTPResponse(status: 502, headers: jsonHeaders, body: data)
            }

            let responseData = try JSONSerialization.data(withJSONObject: responseBody)
            if request.wantsEventStream {
                return HTTPResponse(status: 200, headers: eventStreamHeaders, body: eventStreamData(for: responseBody))
            }
            return HTTPResponse(status: 200, headers: jsonHeaders, body: responseData)
        } catch {
            return .text(status: 502, body: "Proxy request failed: \(error.localizedDescription)")
        }
    }

    private func send(_ response: HTTPResponse, on connection: NWConnection) {
        connection.send(content: response.data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func chatCompletionsURL(for service: CodexService) -> URL? {
        let trimmed = service.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlString: String

        if trimmed.hasSuffix("/chat/completions") {
            urlString = trimmed
        } else if trimmed.hasSuffix("/chat") {
            urlString = trimmed + "/completions"
        } else {
            urlString = trimmed + "/chat/completions"
        }

        return URL(string: urlString)
    }

    func chatCompletionsBody(from data: Data) -> [String: Any]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var body: [String: Any] = [
            "model": root["model"] ?? "",
            "messages": messages(from: root)
        ]

        if let temperature = root["temperature"] {
            body["temperature"] = temperature
        }
        if let maxOutputTokens = root["max_output_tokens"] {
            body["max_tokens"] = maxOutputTokens
        }
        if let tools = chatTools(from: root["tools"]) {
            body["tools"] = tools
        }
        if let toolChoice = root["tool_choice"] {
            body["tool_choice"] = toolChoice
        }

        return body
    }

    private func messages(from root: [String: Any]) -> [[String: Any]] {
        var messages: [[String: Any]] = []

        if let instructions = root["instructions"] as? String, !instructions.isEmpty {
            messages.append(["role": "system", "content": instructions])
        }

        if let input = root["input"] as? String {
            messages.append(["role": "user", "content": input])
            return messages
        }

        guard let input = root["input"] as? [[String: Any]] else {
            return messages
        }

        for item in input {
            let type = item["type"] as? String
            if type == "function_call_output" {
                messages.append([
                    "role": "tool",
                    "tool_call_id": item["call_id"] as? String ?? "",
                    "content": item["output"] as? String ?? ""
                ])
                continue
            }

            if type == "function_call" {
                messages.append([
                    "role": "assistant",
                    "content": NSNull(),
                    "tool_calls": [[
                        "id": item["call_id"] as? String ?? item["id"] as? String ?? UUID().uuidString,
                        "type": "function",
                        "function": [
                            "name": item["name"] as? String ?? "",
                            "arguments": item["arguments"] as? String ?? "{}"
                        ]
                    ]]
                ])
                continue
            }

            let role = chatRole(from: item["role"] as? String)
            let content = textContent(from: item["content"])
            if !content.isEmpty {
                messages.append(["role": role, "content": content])
            }
        }

        return messages
    }

    private func chatRole(from role: String?) -> String {
        switch role ?? "user" {
        case "assistant", "system", "tool", "user":
            return role ?? "user"
        case "developer":
            return "system"
        default:
            return "user"
        }
    }

    private func textContent(from value: Any?) -> String {
        if let text = value as? String {
            return text
        }

        if let content = value as? [[String: Any]] {
            return content.compactMap { part in
                part["text"] as? String
            }
            .joined(separator: "\n")
        }

        if let content = value as? [String: Any] {
            return content["text"] as? String ?? ""
        }

        return ""
    }

    private func chatTools(from value: Any?) -> [[String: Any]]? {
        guard let tools = value as? [[String: Any]] else { return nil }
        let converted = tools.compactMap { tool -> [String: Any]? in
            if tool["type"] as? String != "function" {
                return nil
            }
            if tool["function"] != nil {
                return tool
            }

            return [
                "type": "function",
                "function": [
                    "name": tool["name"] as? String ?? "",
                    "description": tool["description"] as? String ?? "",
                    "parameters": tool["parameters"] ?? [:]
                ]
            ]
        }
        return converted.isEmpty ? nil : converted
    }

    func responsesBody(fromChatCompletionsData data: Data) -> [String: Any]? {
        guard let chat = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = chat["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else {
            return nil
        }

        var output: [[String: Any]] = []
        let content = messageText(from: message)
        if !content.isEmpty {
            output.append([
                "id": "msg_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
                "type": "message",
                "status": "completed",
                "role": "assistant",
                "content": [[
                    "type": "output_text",
                    "text": content,
                    "annotations": []
                ]]
            ])
        }

        if let toolCalls = message["tool_calls"] as? [[String: Any]] {
            for toolCall in toolCalls {
                let function = toolCall["function"] as? [String: Any] ?? [:]
                output.append([
                    "id": "fc_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
                    "type": "function_call",
                    "status": "completed",
                    "call_id": toolCall["id"] as? String ?? UUID().uuidString,
                    "name": function["name"] as? String ?? "",
                    "arguments": function["arguments"] as? String ?? "{}"
                ])
            }
        }

        return [
            "id": "resp_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
            "object": "response",
            "created_at": Int(Date().timeIntervalSince1970),
            "status": "completed",
            "model": chat["model"] ?? "",
            "output": output,
            "usage": responsesUsage(from: chat["usage"])
        ]
    }

    private func messageText(from message: [String: Any]) -> String {
        if let content = message["content"] as? String, !content.isEmpty {
            return content
        }
        if let content = message["reasoning_content"] as? String, !content.isEmpty {
            return content
        }
        if let content = message["content"] as? [[String: Any]] {
            return content.compactMap { part in
                part["text"] as? String
            }
            .joined(separator: "\n")
        }
        return ""
    }

    private func responsesUsage(from value: Any?) -> [String: Any] {
        guard let usage = value as? [String: Any] else { return [:] }
        return [
            "input_tokens": usage["prompt_tokens"] ?? 0,
            "output_tokens": usage["completion_tokens"] ?? 0,
            "total_tokens": usage["total_tokens"] ?? 0
        ]
    }

    func eventStreamData(for responseBody: [String: Any]) -> Data {
        var stream = ""

        stream += sseEvent("response.created", data: [
            "type": "response.created",
            "response": responseBody
        ])

        if let output = responseBody["output"] as? [[String: Any]] {
            for (index, item) in output.enumerated() {
                stream += sseEvent("response.output_item.added", data: [
                    "type": "response.output_item.added",
                    "output_index": index,
                    "item": item
                ])
                stream += sseEvent("response.output_item.done", data: [
                    "type": "response.output_item.done",
                    "output_index": index,
                    "item": item
                ])
            }
        }

        stream += sseEvent("response.completed", data: [
            "type": "response.completed",
            "response": responseBody
        ])
        stream += "event: done\ndata: [DONE]\n\n"

        return Data(stream.utf8)
    }

    private func sseEvent(_ event: String, data: [String: Any]) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return "event: \(event)\ndata: \(json)\n\n"
    }

    private var jsonHeaders: [String: String] {
        ["Content-Type": "application/json"]
    }

    private var eventStreamHeaders: [String: String] {
        [
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "close"
        ]
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    var pathComponents: [String] {
        let pathOnly = path.split(separator: "?", maxSplits: 1).first ?? ""
        return pathOnly
            .split(separator: "/")
            .map(String.init)
    }

    var wantsEventStream: Bool {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return false
        }
        return root["stream"] as? Bool == true
    }

    init?(data: Data) {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)),
              let headerText = String(data: data[..<headerRange.lowerBound], encoding: .utf8) else {
            return nil
        }

        let headerLines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = headerLines.first else { return nil }
        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in headerLines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                headers[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        let bodyStart = headerRange.upperBound
        let contentLength = Int(headers["content-length"] ?? "0") ?? 0
        guard data.count >= bodyStart + contentLength else { return nil }

        method = requestParts[0]
        path = requestParts[1]
        self.headers = headers
        body = data.subdata(in: bodyStart..<(bodyStart + contentLength))
    }
}

private struct HTTPResponse {
    let status: Int
    let headers: [String: String]
    let body: Data

    var data: Data {
        var response = "HTTP/1.1 \(status) \(reasonPhrase)\r\n"
        response += "Content-Length: \(body.count)\r\n"
        for (key, value) in headers {
            response += "\(key): \(value)\r\n"
        }
        response += "\r\n"

        var data = Data(response.utf8)
        data.append(body)
        return data
    }

    private var reasonPhrase: String {
        switch status {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 502: return "Bad Gateway"
        default: return "Error"
        }
    }

    static func text(status: Int, body: String) -> HTTPResponse {
        HTTPResponse(
            status: status,
            headers: ["Content-Type": "text/plain; charset=utf-8"],
            body: Data(body.utf8)
        )
    }

    static func json(_ body: [String: Any], status: Int = 200) -> HTTPResponse {
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
        return HTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json"],
            body: data
        )
    }
}
