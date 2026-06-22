import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData = .empty
    @Published var errorMessage = ""
    @Published var statusMessage = ""
    @Published var isOpenAIAccountLoginRunning = false
    @Published var checkingOpenAIAccountIDs: Set<String> = []
    @Published var proxyStatus: ProxyServerStatus = .notRunning

    private let configWriter = CodexConfigWriter()
    private let openAIAuthManager = OpenAIAuthManager()
    private let compatibilityProxy = CompatibilityProxyServer()
    private let shellIntegration = CodexShellIntegration()

    var selectedService: CodexService? {
        guard let selected = data.selectedModel else { return nil }
        return data.services.first { $0.id == selected.serviceID }
    }

    var selectedModel: CodexModel? {
        guard let selected = data.selectedModel else { return nil }
        return selectedService?.models.first { $0.id == selected.modelID }
    }

    var selectedProfile: CodexProfile? {
        guard let selectedProfileID = data.selectedProfileID else {
            return data.profiles.first
        }
        return data.profiles.first { $0.id == selectedProfileID } ?? data.profiles.first
    }

    var isShellHookInstalled: Bool {
        shellIntegration.isShellHookInstalled()
    }

    init() {
        compatibilityProxy.onStatusChange = { [weak self] status in
            Task { @MainActor in
                self?.proxyStatus = status
            }
        }
        load()
        syncCompatibilityProxy()
    }

    func clearError() {
        errorMessage = ""
        statusMessage = ""
    }

    func clearStatusMessage() {
        statusMessage = ""
    }

    func load() {
        if let stored = try? Data(contentsOf: AppPaths.appData),
           let decoded = try? JSONDecoder().decode(AppData.self, from: stored) {
            data = decoded
        } else if let stored = try? Data(contentsOf: AppPaths.legacyAppData),
                  let decoded = try? JSONDecoder().decode(AppData.self, from: stored) {
            data = decoded
        } else {
            data = defaultData()
            persist()
        }

        ensureDefaultProfiles()

        if data.selectedModel == nil {
            data.selectedModel = data.services.first.flatMap { service in
                service.models.first.map { SelectedModel(serviceID: service.id, modelID: $0.id) }
            }
            persist()
        }

        if data.selectedOpenAIAccountID == nil {
            data.selectedOpenAIAccountID = data.openAIAccounts.first?.id
            persist()
        }

        migrateOpenAIAccountEmails()
        syncActiveProfile(showStatus: false)
    }

    private func migrateOpenAIAccountEmails() {
        var didChange = false
        for index in data.openAIAccounts.indices where data.openAIAccounts[index].email == nil {
            if let email = openAIAuthManager.extractEmail(from: data.openAIAccounts[index].authJSON) {
                data.openAIAccounts[index].email = email
                data.openAIAccounts[index].name = email
                didChange = true
            }
        }

        if didChange {
            persist()
        }
    }

    func select(serviceID: String, modelID: String) {
        let selected = SelectedModel(serviceID: serviceID, modelID: modelID)
        data.selectedModel = selected
        do {
            guard let profile = selectedProfile else {
                errorMessage = "Choose a Codex profile first."
                return
            }
            try configWriter.applySelection(selected, in: data, profile: profile)
            persist()
            errorMessage = ""
            let selectedService = data.services.first { $0.id == serviceID }
            statusMessage = selectedService?.useCompatibilityProxy == true
                ? "Restart Codex and keep this app running for the proxy."
                : "Restart Codex to use this selection."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addOpenAIAccount() {
        guard !isOpenAIAccountLoginRunning else {
            errorMessage = AppError.openAIAccountLoginInProgress.localizedDescription
            return
        }

        isOpenAIAccountLoginRunning = true
        errorMessage = ""
        statusMessage = "Opening Codex login in your browser..."

        Task {
            do {
                let accountName = "OpenAI \(data.openAIAccounts.count + 1)"
                let account = try await openAIAuthManager.loginAccount(suggestedName: accountName)
                data.openAIAccounts.append(account)
                data.selectedOpenAIAccountID = account.id
                persist()

                try configWriter.restoreOpenAIAuth(from: data)
                if data.selectedModel?.serviceID == "openai",
                   let selected = data.selectedModel {
                    try configWriter.applySelection(selected, in: data)
                }

                statusMessage = "Saved \(account.displayName). Restart Codex to use this account."
                errorMessage = ""
            } catch {
                statusMessage = ""
                errorMessage = error.localizedDescription
            }
            isOpenAIAccountLoginRunning = false
        }
    }

    func selectOpenAIAccount(_ accountID: String) {
        data.selectedOpenAIAccountID = accountID
        persist()

        do {
            try configWriter.restoreOpenAIAuth(from: data)
            if data.selectedModel?.serviceID == "openai",
               let selected = data.selectedModel {
                try configWriter.applySelection(selected, in: data)
            }
            statusMessage = "Switched OpenAI account. Restart Codex to use it."
            errorMessage = ""
        } catch {
            statusMessage = ""
            errorMessage = error.localizedDescription
        }
    }

    func profileHealth(for profile: CodexProfile) -> ProfileHealth {
        ProfileHealthScanner().health(for: profile)
    }

    func selectProfile(_ profileID: String) {
        data.selectedProfileID = profileID
        persist()
        syncActiveProfile(showStatus: true)
    }

    func launchCommand(for profile: CodexProfile) -> String {
        CodexLauncher(profile: profile).shellCommand()
    }

    func copyLaunchCommand(for profile: CodexProfile) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(launchCommand(for: profile), forType: .string)
        statusMessage = "Copied launch command for \(profile.name)."
        errorMessage = ""
    }

    func installShellIntegration() {
        guard let profile = selectedProfile else {
            errorMessage = "Choose a Codex profile first."
            return
        }

        do {
            try activateProfile(profile)
            _ = try shellIntegration.installShellHook()
            statusMessage = "Installed terminal hook. Open a new terminal or source ~/.zshrc once."
            errorMessage = ""
            objectWillChange.send()
        } catch {
            statusMessage = ""
            errorMessage = error.localizedDescription
        }
    }

    func openProfileFolder(_ profile: CodexProfile) {
        NSWorkspace.shared.open(URL(fileURLWithPath: profile.path, isDirectory: true))
    }

    func openSelectedProfileConfig() {
        guard let profile = selectedProfile else {
            errorMessage = "Choose a Codex profile first."
            return
        }

        let paths = AppPaths.profilePaths(for: profile)
        if FileManager.default.fileExists(atPath: paths.config.path) {
            NSWorkspace.shared.open(paths.config)
            errorMessage = ""
        } else {
            NSWorkspace.shared.open(paths.home)
            statusMessage = "\(profile.name) does not have a config.toml yet."
            errorMessage = ""
        }
    }

    func checkOpenAIAccounts() {
        guard !data.openAIAccounts.isEmpty else { return }

        for account in data.openAIAccounts where !checkingOpenAIAccountIDs.contains(account.id) {
            checkOpenAIAccount(account)
        }
    }

    private func checkOpenAIAccount(_ account: OpenAIAccount) {
        if let index = data.openAIAccounts.firstIndex(where: { $0.id == account.id }) {
            data.openAIAccounts[index].credentialStatus = .unchecked
            data.openAIAccounts[index].credentialMessage = nil
        }
        checkingOpenAIAccountIDs.insert(account.id)

        Task {
            let result = await openAIAuthManager.validateAccount(account)
            if let index = data.openAIAccounts.firstIndex(where: { $0.id == account.id }) {
                if let authJSON = result.authJSON {
                    data.openAIAccounts[index].authJSON = authJSON
                    data.openAIAccounts[index].accountID = openAIAuthManager.extractAccountID(from: authJSON)
                    if let email = openAIAuthManager.extractEmail(from: authJSON) {
                        data.openAIAccounts[index].email = email
                        data.openAIAccounts[index].name = email
                    }
                }
                data.openAIAccounts[index].credentialStatus = result.status
                data.openAIAccounts[index].credentialMessage = result.message
                persist()

                if result.authJSON != nil,
                   data.selectedOpenAIAccountID == account.id {
                    do {
                        try configWriter.restoreOpenAIAuth(from: data)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            checkingOpenAIAccountIDs.remove(account.id)
        }
    }

    func deleteOpenAIAccount(_ account: OpenAIAccount) {
        data.openAIAccounts.removeAll { $0.id == account.id }
        if data.selectedOpenAIAccountID == account.id {
            data.selectedOpenAIAccountID = data.openAIAccounts.first?.id
        }
        persist()

        do {
            try configWriter.restoreOpenAIAuth(from: data)
            if data.selectedModel?.serviceID == "openai",
               let selected = data.selectedModel {
                try configWriter.applySelection(selected, in: data)
            }
            statusMessage = data.selectedOpenAIAccountID == nil
                ? "Deleted OpenAI account."
                : "Deleted OpenAI account. Restart Codex to use the new selection."
            errorMessage = ""
        } catch {
            statusMessage = ""
            errorMessage = error.localizedDescription
        }
    }

    func saveService(originalID: String?, form: ServiceFormData) {
        let providerName = form.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingID = originalID ?? form.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let serviceID = existingID.isEmpty ? uniqueServiceID(for: providerName) : existingID
        let models = parseModelRows(form.modelsText)

        guard isValidServiceID(serviceID) else {
            errorMessage = AppError.invalidServiceID.localizedDescription
            return
        }
        guard !models.isEmpty else {
            errorMessage = AppError.invalidModelList.localizedDescription
            return
        }
        if data.services.contains(where: { $0.id == serviceID && $0.id != originalID }) {
            errorMessage = AppError.duplicateServiceID.localizedDescription
            return
        }

        let service = CodexService(
            id: serviceID,
            name: providerName.isEmpty ? serviceID : providerName,
            baseURL: form.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            envKey: form.envKey.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: form.apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            useCompatibilityProxy: form.useCompatibilityProxy,
            models: models
        )

        if let originalID,
           let index = data.services.firstIndex(where: { $0.id == originalID }) {
            let previousSelection = data.selectedModel
            data.services[index] = service
            if data.selectedModel?.serviceID == originalID {
                let modelID = models.first { $0.id == previousSelection?.modelID }?.id ?? models[0].id
                data.selectedModel = SelectedModel(serviceID: service.id, modelID: modelID)
            }
        } else {
            data.services.append(service)
            data.selectedModel = SelectedModel(serviceID: service.id, modelID: models[0].id)
        }

        persist()
        if let selected = data.selectedModel {
            select(serviceID: selected.serviceID, modelID: selected.modelID)
        }
    }

    func deleteService(_ service: CodexService) {
        guard data.services.count > 1 else { return }
        data.services.removeAll { $0.id == service.id }
        if data.selectedModel?.serviceID == service.id {
            data.selectedModel = data.services.first.flatMap { nextService in
                nextService.models.first.map {
                    SelectedModel(serviceID: nextService.id, modelID: $0.id)
                }
            }
        }
        persist()
        if let selected = data.selectedModel {
            select(serviceID: selected.serviceID, modelID: selected.modelID)
        }
    }

    private func uniqueServiceID(for name: String) -> String {
        let baseID = slugify(name)
        var candidate = baseID
        var suffix = 2

        while data.services.contains(where: { $0.id == candidate }) {
            candidate = "\(baseID)-\(suffix)"
            suffix += 1
        }

        return candidate
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: AppPaths.appSupportDirectory,
                withIntermediateDirectories: true
            )
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: AppPaths.appData, options: .atomic)
            syncCompatibilityProxy()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncCompatibilityProxy() {
        compatibilityProxy.updateService(selectedService)
    }

    private func syncActiveProfile(showStatus: Bool) {
        guard let profile = selectedProfile else { return }

        do {
            try activateProfile(profile)
            if showStatus {
                statusMessage = shellIntegration.isShellHookInstalled()
                    ? "Activated \(profile.name). Run codex again."
                    : "Activated \(profile.name). Install terminal hook once for plain codex."
            }
            errorMessage = ""
        } catch {
            statusMessage = ""
            errorMessage = error.localizedDescription
        }
    }

    private func activateProfile(_ profile: CodexProfile) throws {
        try shellIntegration.writeActiveProfile(profile)
        setLaunchEnvironment(name: "CODEX_HOME", value: profile.path)
    }

    private func ensureDefaultProfiles() {
        let defaults = CodexProfile.defaultProfiles()
        var existingByID = Dictionary(uniqueKeysWithValues: data.profiles.map { ($0.id, $0) })
        var merged: [CodexProfile] = []

        for profile in defaults {
            if let existing = existingByID.removeValue(forKey: profile.id) {
                merged.append(existing)
            } else {
                merged.append(profile)
            }
        }

        merged.append(contentsOf: existingByID.values.sorted { $0.name < $1.name })
        data.profiles = merged
        if data.selectedProfileID == nil || !data.profiles.contains(where: { $0.id == data.selectedProfileID }) {
            data.selectedProfileID = data.profiles.first?.id
        }
        persist()
    }

    private func defaultData() -> AppData {
        AppData(
            services: [
                CodexService(
                    id: "openai",
                    name: "OpenAI",
                    baseURL: "",
                    envKey: "",
                    apiKey: "",
                    useCompatibilityProxy: false,
                    models: [
                        CodexModel(id: "gpt-5.5", name: "gpt-5.5"),
                        CodexModel(id: "gpt-5.4-mini", name: "gpt-5.4-mini")
                    ]
                ),
                CodexService(
                    id: "openrouter",
                    name: "OpenRouter",
                    baseURL: "https://openrouter.ai/api/v1",
                    envKey: "OPENROUTER_API_KEY",
                    apiKey: "",
                    useCompatibilityProxy: false,
                    models: [
                        CodexModel(id: "moonshotai/kimi-k2.5", name: "moonshotai/kimi-k2.5"),
                        CodexModel(id: "google/gemini-3.5-flash", name: "google/gemini-3.5-flash")
                    ]
                )
            ],
            selectedModel: SelectedModel(serviceID: "openai", modelID: "gpt-5.5"),
            profiles: CodexProfile.defaultProfiles(),
            selectedProfileID: "primary",
            openAIAccounts: [],
            selectedOpenAIAccountID: nil
        )
    }

    private func setLaunchEnvironment(name: String, value: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["setenv", name, value]
        try? process.run()
    }
}
