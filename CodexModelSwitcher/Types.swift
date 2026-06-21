import Foundation

struct CodexService: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var baseURL: String
    var envKey: String
    var apiKey: String
    var models: [CodexModel]

    var requiresAPIKey: Bool {
        !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CodexModel: Identifiable, Codable, Equatable {
    var id: String
    var name: String
}

struct SelectedModel: Codable, Equatable {
    var serviceID: String
    var modelID: String
}

struct AppData: Codable {
    var services: [CodexService]
    var selectedModel: SelectedModel?
    var openAIAccounts: [OpenAIAccount]
    var selectedOpenAIAccountID: String?

    static let empty = AppData(services: [], selectedModel: nil)

    init(
        services: [CodexService],
        selectedModel: SelectedModel?,
        openAIAccounts: [OpenAIAccount] = [],
        selectedOpenAIAccountID: String? = nil
    ) {
        self.services = services
        self.selectedModel = selectedModel
        self.openAIAccounts = openAIAccounts
        self.selectedOpenAIAccountID = selectedOpenAIAccountID
    }

    enum CodingKeys: String, CodingKey {
        case services
        case selectedModel
        case openAIAccounts
        case selectedOpenAIAccountID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        services = try container.decode([CodexService].self, forKey: .services)
        selectedModel = try container.decodeIfPresent(SelectedModel.self, forKey: .selectedModel)
        openAIAccounts = try container.decodeIfPresent([OpenAIAccount].self, forKey: .openAIAccounts) ?? []
        selectedOpenAIAccountID = try container.decodeIfPresent(String.self, forKey: .selectedOpenAIAccountID)
    }
}

struct OpenAIAccount: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var authJSON: String
    var accountID: String?
    var email: String?
    var credentialStatus: OpenAIAccountCredentialStatus
    var credentialMessage: String?
    var createdAt: Date

    var displayName: String {
        email ?? name
    }

    init(
        id: String,
        name: String,
        authJSON: String,
        accountID: String?,
        email: String?,
        credentialStatus: OpenAIAccountCredentialStatus = .unchecked,
        credentialMessage: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.authJSON = authJSON
        self.accountID = accountID
        self.email = email
        self.credentialStatus = credentialStatus
        self.credentialMessage = credentialMessage
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case authJSON
        case accountID
        case email
        case credentialStatus
        case credentialMessage
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        authJSON = try container.decode(String.self, forKey: .authJSON)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        credentialStatus = try container.decodeIfPresent(
            OpenAIAccountCredentialStatus.self,
            forKey: .credentialStatus
        ) ?? .unchecked
        credentialMessage = try container.decodeIfPresent(String.self, forKey: .credentialMessage)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

enum OpenAIAccountCredentialStatus: String, Codable {
    case unchecked
    case valid
    case invalid
}

struct ServiceFormData: Equatable {
    var id: String
    var name: String
    var baseURL: String
    var envKey: String
    var apiKey: String
    var modelsText: String

    init(service: CodexService? = nil) {
        id = service?.id ?? ""
        name = service?.name ?? ""
        baseURL = service?.baseURL ?? ""
        envKey = service?.envKey ?? ""
        apiKey = service?.apiKey ?? ""
        modelsText = service?.models.map(\.id).joined(separator: "\n") ?? ""
    }
}
