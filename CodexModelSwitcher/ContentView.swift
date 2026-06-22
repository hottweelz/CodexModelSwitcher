import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editorSession: EditorSession?
    @State private var isShowingOpenAIAccountWarning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Divider()
            bodySection
            if editorSession == nil {
                Divider()
                footer
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: panelWidth)
        .frame(maxHeight: maxPanelHeight, alignment: .top)
        .background {
            WindowTransparencyConfigurator()
                .allowsHitTesting(false)
        }
        .onDisappear {
            store.clearStatusMessage()
        }
        .alert("Add OpenAI account", isPresented: $isShowingOpenAIAccountWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Continue Login") {
                store.addOpenAIAccount()
            }
        } message: {
            Text("Codex will open login in your browser. If you log out of an existing ChatGPT account during this flow, that saved account may stop working. To keep saved accounts valid, use a separate browser profile or private browser for the new account.")
        }
    }

    private var panelWidth: CGFloat {
        390
    }

    private var maxPanelHeight: CGFloat {
        ((NSScreen.main?.visibleFrame.height ?? 900) * 0.7).rounded(.down)
    }

    private var maxBodyHeight: CGFloat {
        min(editorSession == nil ? 520 : maxPanelHeight - 52, maxPanelHeight - 78)
    }

    private var header: some View {
        HStack(spacing: 10) {
            if editorSession != nil {
                Button {
                    store.clearError()
                    editorSession = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .help("Back")

                Text(editorSession?.title ?? "")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Button("Save") {
                    saveEditorSession()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 34, height: 34)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Codex Profiles")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                    Text(currentSelectionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    editSelectedService()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .help("Provider settings")
                .disabled(store.selectedService == nil)

                Button {
                    store.clearError()
                    editorSession = EditorSession(
                        title: "Add Provider",
                        originalID: nil,
                        form: ServiceFormData()
                    )
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .help("Add service")
            }
        }
    }

    @ViewBuilder
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let editorSession {
                ScrollView {
                    editorView(for: editorSession)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: maxBodyHeight, alignment: .top)
            } else {
                serviceList
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else if !store.statusMessage.isEmpty {
                Text(store.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxHeight: maxBodyHeight, alignment: .top)
    }

    private var serviceList: some View {
        ScrollView {
            profileAndServiceStack
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: min(430, maxBodyHeight), maxHeight: maxBodyHeight, alignment: .top)
    }

    private var profileAndServiceStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            profileStack
            selectedTargetNotice
            Divider()
            Text("Models")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            serviceStack
        }
    }

    private var profileStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Profiles")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ForEach(store.data.profiles) { profile in
                ProfileRowView(profile: profile)
                    .environmentObject(store)
            }
        }
    }

    private var selectedTargetNotice: some View {
        HStack(spacing: 5) {
            Image(systemName: "scope")
                .foregroundStyle(.secondary)
            Text(selectedTargetNoticeText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 4)
    }

    private var serviceStack: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(store.data.services.enumerated()), id: \.element.id) { index, service in
                VStack(spacing: 0) {
                    ServiceSectionView(
                        service: service,
                        onAddOpenAIAccount: {
                            isShowingOpenAIAccountWarning = true
                        },
                        onEdit: {
                            store.clearError()
                            editorSession = EditorSession(
                                title: "Provider Settings",
                                originalID: service.id,
                                form: ServiceFormData(service: service)
                            )
                        }
                    )
                    .environmentObject(store)

                    if index < store.data.services.count - 1 {
                        Divider()
                            .padding(.leading, 8)
                    }
                }
            }
        }
    }

    private func editorView(for editorSession: EditorSession) -> some View {
        ServiceEditorView(
            title: editorSession.title,
            originalID: editorSession.originalID,
            form: Binding(
                get: { self.editorSession?.form ?? editorSession.form },
                set: { self.editorSession?.form = $0 }
            )
        )
        .id(editorSession.id)
    }

    private func saveEditorSession() {
        guard let editorSession else { return }
        store.saveService(originalID: editorSession.originalID, form: editorSession.form)
        if store.errorMessage.isEmpty {
            self.editorSession = nil
        }
    }

    private func editSelectedService() {
        guard let service = store.selectedService else { return }
        store.clearError()
        editorSession = EditorSession(
            title: "Provider Settings",
            originalID: service.id,
            form: ServiceFormData(service: service)
        )
    }

    private var footer: some View {
        HStack {
            if shouldShowProxyStatus {
                proxyStatusView
            } else {
                selectedProfileFooter
            }

            Spacer()

            Button {
                store.installShellIntegration()
            } label: {
                Image(systemName: store.isShellHookInstalled ? "terminal.fill" : "terminal")
            }
            .buttonStyle(.plain)
            .foregroundStyle(store.isShellHookInstalled ? Color.secondary : Color.accentColor)
            .help(shellIntegrationHelp)

            Button("config.toml") {
                store.openSelectedProfileConfig()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var proxyStatusView: some View {
        HStack(spacing: 4) {
            switch store.proxyStatus {
            case .starting:
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.55)
                    .frame(width: 10, height: 10)
            case .notRunning:
                Circle()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 10, height: 10)
            case .active:
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            case .error:
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
            }

            Text(proxyStatusLabel)
                .foregroundStyle(.secondary)
        }
        .help(proxyStatusHelp)
    }

    private var selectedProfileFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
            Text(selectedProfileFooterText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .help(selectedProfileFooterHelp)
    }

    private var shouldShowProxyStatus: Bool {
        if store.selectedService?.useCompatibilityProxy == true {
            return true
        }
        switch store.proxyStatus {
        case .starting, .active, .error:
            return true
        case .notRunning:
            return false
        }
    }

    private var proxyStatusLabel: String {
        switch store.proxyStatus {
        case .starting:
            return "Proxy starting"
        case .notRunning:
            return "Proxy not running"
        case .active:
            return "Proxy active \(CompatibilityProxyServer.address)"
        case .error:
            return "Proxy error"
        }
    }

    private var proxyStatusHelp: String {
        switch store.proxyStatus {
        case .starting:
            return "Proxy server is starting"
        case .notRunning:
            return "Proxy server is not running"
        case .active:
            return "Proxy server is active"
        case .error:
            return "Proxy server failed to start"
        }
    }

    private var currentSelectionText: String {
        guard let profile = store.selectedProfile,
              let service = store.selectedService,
              let model = store.selectedModel else {
            return "No profile selected"
        }

        return "\(profile.name) / \(service.name) / \(model.name)"
    }

    private var selectedProfileFooterText: String {
        guard let profile = store.selectedProfile else {
            return "No profile"
        }
        return ProfileDisplayText.selectedProfileFooter(for: profile)
    }

    private var selectedProfileFooterHelp: String {
        guard let profile = store.selectedProfile else {
            return "No Codex profile selected"
        }
        return "Selected Codex profile: \(profile.path)"
    }

    private var shellIntegrationHelp: String {
        store.isShellHookInstalled
            ? "Terminal hook installed; plain codex follows selected profile"
            : "Install terminal hook so plain codex follows selected profile"
    }

    private func shortPath(_ path: String) -> String {
        ProfileDisplayText.shortPath(path)
    }

    private var selectedTargetNoticeText: String {
        guard let profile = store.selectedProfile else {
            return "Choose a target profile"
        }
        return ProfileDisplayText.modelSelectionTarget(for: profile)
    }
}

private struct EditorSession: Identifiable {
    let id = UUID()
    let title: String
    let originalID: String?
    var form: ServiceFormData
}

private struct ProfileRowView: View {
    @EnvironmentObject private var store: AppStore
    let profile: CodexProfile
    @State private var isHovering = false

    var body: some View {
        let health = store.profileHealth(for: profile)

        HStack(spacing: 6) {
            Button {
                store.selectProfile(profile.id)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: iconName(for: health.status))
                        .foregroundStyle(iconColor(for: health.status))
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.name)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .lineLimit(1)
                        Text(detailText(for: health))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if store.data.selectedProfileID == profile.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHovering {
                Button {
                    store.copyLaunchCommand(for: profile)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help("Copy launch command")

                Button {
                    store.openProfileFolder(profile)
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help("Open profile folder")
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(store.data.selectedProfileID == profile.id ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { isHovering = $0 }
    }

    private func detailText(for health: ProfileHealth) -> String {
        let prefix = store.data.selectedProfileID == profile.id ? "Target - " : ""
        let detail: String
        switch health.status {
        case .missing:
            detail = "\(shortPath(profile.path)) - missing"
        case .notLoggedIn:
            detail = "\(shortPath(profile.path)) - not logged in"
        case .noConfig:
            detail = "\(shortPath(profile.path)) - no config"
        case .ready:
            let summary = [health.selectedProvider, health.selectedModel]
                .compactMap { $0 }
                .joined(separator: " / ")
            detail = summary.isEmpty ? shortPath(profile.path) : summary
        }
        return prefix + detail
    }

    private func iconName(for status: ProfileHealthStatus) -> String {
        switch status {
        case .missing:
            return "questionmark.circle"
        case .notLoggedIn:
            return "person.crop.circle.badge.exclamationmark"
        case .noConfig:
            return "doc.badge.gearshape"
        case .ready:
            return "checkmark.circle.fill"
        }
    }

    private func iconColor(for status: ProfileHealthStatus) -> Color {
        switch status {
        case .ready:
            return .green
        case .missing, .notLoggedIn, .noConfig:
            return .orange
        }
    }

    private func shortPath(_ path: String) -> String {
        ProfileDisplayText.shortPath(path)
    }
}

private struct ServiceSectionView: View {
    @EnvironmentObject private var store: AppStore
    let service: CodexService
    let onAddOpenAIAccount: () -> Void
    let onEdit: () -> Void
    @State private var isHovering = false
    @State private var isOpenAIAccountDropdownOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if service.id == "openai" {
                    openAIAccountMenu
                } else {
                    Text(service.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                }

                Spacer()

                if service.id == "openai" {
                    openAIAccountActions
                } else {
                    providerActions
                }
            }

            serviceStatusLine

            VStack(spacing: 3) {
                ForEach(service.models) { model in
                    Button {
                        store.select(serviceID: service.id, modelID: model.id)
                    } label: {
                        HStack {
                            Image(systemName: isSelected(model) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected(model) ? Color.accentColor : Color.secondary)
                            Text(model.name)
                                .font(.body)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(isSelected(model) ? Color.accentColor.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
            }

        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func isSelected(_ model: CodexModel) -> Bool {
        store.data.selectedModel == SelectedModel(serviceID: service.id, modelID: model.id)
    }

    private var providerActions: some View {
        HStack(spacing: 4) {
            Button {
                onEdit()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help("Provider settings")

            Button(role: .destructive) {
                store.deleteService(service)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help("Delete service")
            .disabled(store.data.services.count == 1)
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
        }
    }

    @ViewBuilder
    private var serviceStatusLine: some View {
        if service.requiresAPIKey || service.useCompatibilityProxy {
            HStack(spacing: 8) {
                if service.requiresAPIKey {
                    Label(service.apiKey.isEmpty ? "No API key" : "API key saved", systemImage: service.apiKey.isEmpty ? "key.slash" : "key.fill")
                        .foregroundStyle(service.apiKey.isEmpty ? .orange : .secondary)
                }

                if service.useCompatibilityProxy {
                    Label("Proxy enabled", systemImage: "network")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .labelStyle(.titleAndIcon)
        }
    }

    private var openAIAccountActions: some View {
        HStack(spacing: 4) {
            if store.isOpenAIAccountLoginRunning {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.65)
                    .frame(width: 22, height: 22)
            } else {
                Button {
                    onAddOpenAIAccount()
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .help("Add OpenAI account")
            }

            if let selectedAccount = selectedAccount {
                Button(role: .destructive) {
                    store.deleteOpenAIAccount(selectedAccount)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .help("Delete saved OpenAI account")
            }
        }
    }

    private var openAIAccountMenu: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                isOpenAIAccountDropdownOpen.toggle()
            } label: {
                HStack(spacing: 5) {
                    Text("OpenAI")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(selectedOpenAIAccountName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isOpenAIAccountDropdownOpen, arrowEdge: .top) {
                openAIAccountDropdown
            }
            .onChange(of: isOpenAIAccountDropdownOpen) { _, isOpen in
                if isOpen {
                    store.checkOpenAIAccounts()
                }
            }

            if let selectedAccount = selectedAccount,
               isOpenAIAccountInvalid(selectedAccount) {
                Text(selectedAccount.credentialMessage ?? invalidOpenAIAccountMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var openAIAccountDropdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            if store.data.openAIAccounts.isEmpty {
                Text("Using default login")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.data.openAIAccounts) { account in
                    Button {
                        store.selectOpenAIAccount(account.id)
                        isOpenAIAccountDropdownOpen = false
                    } label: {
                        accountMenuLabel(account)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .frame(width: 280, alignment: .leading)
        .onAppear {
            store.checkOpenAIAccounts()
        }
    }

    private var selectedAccount: OpenAIAccount? {
        guard let accountID = store.data.selectedOpenAIAccountID else {
            return nil
        }
        return store.data.openAIAccounts.first { $0.id == accountID }
    }

    private var selectedOpenAIAccountName: String {
        selectedAccount?.displayName ?? "default"
    }

    private func accountMenuLabel(_ account: OpenAIAccount) -> some View {
        HStack(alignment: .center, spacing: 8) {
            accountCredentialIcon(account)

            VStack(alignment: .leading, spacing: 1) {
                Text(account.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if isOpenAIAccountInvalid(account) {
                    Text(account.credentialMessage ?? invalidOpenAIAccountMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }

            Spacer()

            if store.data.selectedOpenAIAccountID == account.id {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func accountCredentialIcon(_ account: OpenAIAccount) -> some View {
        if store.checkingOpenAIAccountIDs.contains(account.id) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 16, height: 16)
        } else {
            if isOpenAIAccountInvalid(account) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 16, height: 16)
            } else {
                Color.clear
                    .frame(width: 16, height: 16)
            }
        }
    }

    private func isOpenAIAccountInvalid(_ account: OpenAIAccount) -> Bool {
        !store.checkingOpenAIAccountIDs.contains(account.id) && account.credentialStatus == .invalid
    }

    private var invalidOpenAIAccountMessage: String {
        "Not valid. Please re-login."
    }
}

struct ServiceEditorView: View {
    let title: String
    let originalID: String?
    @Binding var form: ServiceFormData

    init(
        title: String,
        originalID: String?,
        form: Binding<ServiceFormData>
    ) {
        self.title = title
        self.originalID = originalID
        _form = form
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                fieldRow("Name", text: $form.name, prompt: "OpenRouter")
                fieldRow("Base URL", text: $form.baseURL, prompt: "https://api.example.com/v1")
                fieldRow("Env key", text: $form.envKey, prompt: "EXAMPLE_API_KEY")

                GridRow {
                    Text("Advanced")
                        .foregroundStyle(.secondary)
                    Toggle("Local compatibility proxy", isOn: $form.useCompatibilityProxy)
                        .toggleStyle(.checkbox)
                }

                GridRow(alignment: .top) {
                    Text("API key")
                        .foregroundStyle(.secondary)
                        .padding(.top, 5)
                    SecureField("Provider API key", text: $form.apiKey)
                }

                GridRow(alignment: .top) {
                    Text("Models")
                        .foregroundStyle(.secondary)
                        .padding(.top, 5)
                    TextEditor(text: $form.modelsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 120)
                        .scrollContentBackground(.hidden)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                        }
                }
            }

            Text("One model ID per line.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func fieldRow(_ label: String, text: Binding<String>, prompt: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    ContentView()
        .environmentObject(AppStore())
}
#endif
