import SwiftUI
import SubstratalKit

/// USR-01 — Users. Find and manage user accounts (`GET /users`).
/// The first screen built against the live API; it sets the pattern the others
/// follow: a view model with an explicit state machine, the spec's controls,
/// and loading / empty / error states.
struct UsersView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var viewModel = UsersViewModel()
    @State private var selection = Set<String>()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loading where viewModel.rows.isEmpty:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let problem) where viewModel.rows.isEmpty:
                ContentUnavailableView {
                    Label("Couldn't load users", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(problem)
                } actions: {
                    Button("Try Again") { Task { await reload() } }
                }
            default:
                if viewModel.rows.isEmpty {
                    ContentUnavailableView.search(text: viewModel.filter.query)
                } else {
                    table
                }
            }
        }
        .searchable(text: $viewModel.filter.query, placement: .toolbar, prompt: "Name, email, or usr_ ID")
        .toolbar {
            ToolbarItem {
                Picker("Status", selection: $viewModel.filter.status) {
                    Text("All").tag(DirectoryService.Filter.Status?.none)
                    ForEach(DirectoryService.Filter.Status.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(Optional(status))
                    }
                }
                .pickerStyle(.menu)
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Invite User", systemImage: "person.badge.plus") {}
                    .disabled(!model.capabilities.has("users.manage"))
                    .help(model.capabilities.has("users.manage") ? "Invite user" : "Needs users.manage")
            }
        }
        .task(id: viewModel.filter) {
            // Debounced 300 ms (SCREENS.md USR-01).
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    private var table: some View {
        Table(viewModel.rows, selection: $selection) {
            TableColumn("Email") { row in
                Text(row.user.email ?? "—")
            }
            TableColumn("Status") { row in
                Text(row.user.status?.rawValue.capitalized ?? "—")
                    .foregroundStyle(row.user.status == .suspended ? .orange : palette.text)
            }
            .width(90)
            TableColumn("ID") { row in
                Text(row.id).font(.body.monospaced()).textSelection(.enabled)
            }
            TableColumn("Last sign-in") { row in
                Text(row.user.lastLoginAt.map { $0.formatted(.relative(presentation: .named)) } ?? "Never")
            }
            .width(120)
            TableColumn("Created") { row in
                Text(row.user.createdAt?.formatted(date: .abbreviated, time: .omitted) ?? "")
            }
            .width(110)
        }
        .contextMenu(forSelectionType: String.self) { ids in
            Button("Copy ID") { copy(ids.sorted().joined(separator: "\n")) }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.nextCursor != nil {
                Button("Load More") { Task { await viewModel.loadMore(using: model.services.directory) } }
                    .padding(8)
            }
        }
    }

    private func reload() async {
        await viewModel.load(using: model.services.directory)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// A table row. The generated `User.id` is optional in the schema; rows need a
/// stable non-optional identity.
struct UserRow: Identifiable, Sendable {
    let id: String
    let user: DirectoryService.User
}

@MainActor @Observable
final class UsersViewModel {
    enum State: Equatable { case idle, loading, loaded, failed(String) }

    var filter = DirectoryService.Filter()
    private(set) var state: State = .idle
    private(set) var rows: [UserRow] = []
    private(set) var nextCursor: String?

    func load(using directory: DirectoryService) async {
        state = .loading
        do {
            let page = try await directory.list(filter)
            rows = Self.rows(page.users)
            nextCursor = page.nextCursor
            state = .loaded
        } catch {
            rows = []
            state = .failed(String(describing: error))
        }
    }

    func loadMore(using directory: DirectoryService) async {
        guard let cursor = nextCursor else { return }
        do {
            let page = try await directory.list(filter, cursor: cursor)
            rows += Self.rows(page.users)
            nextCursor = page.nextCursor
        } catch {
            state = .failed(String(describing: error))
        }
    }

    private static func rows(_ users: [DirectoryService.User]) -> [UserRow] {
        users.compactMap { user in user.id.map { UserRow(id: $0, user: user) } }
    }
}
