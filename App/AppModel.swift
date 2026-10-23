import Foundation
import Observation
import SubstratalKit

/// App-wide state shared by every window: the session, Capabilities, the API
/// environment and version status. Per-window navigation lives in
/// `WindowNavigation`.
@MainActor @Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn(userID: String)
    }

    private(set) var phase: Phase = .launching
    private(set) var capabilities: Capabilities = .none
    private(set) var versionStatus: APIVersionStatus = .current
    private(set) var environment: APIEnvironment

    let catalog = ScreenCatalog.bundled
    let resolver: RouteResolver
    let help = HelpLinks(bundle: .main)
    let theme = ThemeStore()

    private(set) var services: Services

    /// Everything bound to one API environment. Switching environment rebuilds it,
    /// so a token from one environment is never sent to another.
    struct Services {
        let session: SessionStore
        let client: Client
        let auth: AuthService
        let capabilities: CapabilitiesLoader
        let directory: DirectoryService
        let versionMonitor: APIVersionMonitor
    }

    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    private static let environmentKey = "api.environment"

    init() {
        let initial = Self.launchOverride ?? Self.savedEnvironment ?? .production
        environment = initial
        resolver = RouteResolver(catalog: catalog)
        services = Self.makeServices(for: initial)
        observeVersion()
    }

    private static var savedEnvironment: APIEnvironment? {
        UserDefaults.standard.data(forKey: environmentKey)
            .flatMap { try? JSONDecoder().decode(APIEnvironment.self, from: $0) }
    }

    /// Development and UI tests: `-SubstratalAPIBaseURL http://localhost:8080`
    /// on the command line points this run at another API without saving it.
    private static var launchOverride: APIEnvironment? {
        guard let value = UserDefaults.standard.string(forKey: "SubstratalAPIBaseURL"),
              let url = URL(string: value) else { return nil }
        return url.host() == "api.substratalapps.com" ? .production : .local(url)
    }

    private static func makeServices(for environment: APIEnvironment) -> Services {
        // One Keychain item per environment host.
        let session = SessionStore(accountKey: "refresh_token.\(environment.baseURL.host() ?? "local")")
        let monitor = APIVersionMonitor()
        let client = APIClientFactory.make(
            environment: environment,
            versionMonitor: monitor,
            token: { try? await session.accessToken() },
            appVersion: appVersion
        )
        let auth = AuthService(client: client, session: session)
        return Services(
            session: session,
            client: client,
            auth: auth,
            capabilities: CapabilitiesLoader(client: client),
            directory: DirectoryService(client: client),
            versionMonitor: monitor
        )
    }

    private func observeVersion() {
        versionStatus = services.versionMonitor.status
        services.versionMonitor.onChange { [weak self] status in
            Task { @MainActor in self?.versionStatus = status }
        }
    }

    // MARK: Session

    /// Resume a stored session at launch, if there is one.
    func launch() async {
        let auth = services.auth
        await services.session.setRefresher { try await auth.refresh($0) }
        guard await services.session.hasStoredSession else {
            phase = .signedOut
            return
        }
        do {
            let tokens = try await services.session.resume()
            await didSignIn(userID: tokens.userID)
        } catch {
            phase = .signedOut
        }
    }

    func signIn(email: String, password: String, testMode: Bool) async throws -> AuthService.SignInResult {
        let result = try await services.auth.signIn(email: email, password: password, testMode: testMode)
        if case .signedIn(let userID) = result { await didSignIn(userID: userID) }
        return result
    }

    func verifyMFA(mfaToken: String, code: String?, recoveryCode: String?) async throws {
        let userID = try await services.auth.verifyMFA(mfaToken: mfaToken, code: code, recoveryCode: recoveryCode)
        await didSignIn(userID: userID)
    }

    func signOut() async {
        await services.auth.signOut()
        capabilities = .none
        phase = .signedOut
    }

    private func didSignIn(userID: String) async {
        phase = .signedIn(userID: userID)
        await refreshCapabilities()
    }

    /// On sign-in, on foreground, and after any `403`.
    func refreshCapabilities() async {
        guard case .signedIn(let userID) = phase else { return }
        do {
            capabilities = try await services.capabilities.load(userID: userID)
        } catch {
            // Keep the last known Capabilities; the server stays the authority.
        }
    }

    // MARK: Environment

    func switchEnvironment(to new: APIEnvironment) async {
        guard new != environment else { return }
        await signOut()
        environment = new
        UserDefaults.standard.set(try? JSONEncoder().encode(new), forKey: Self.environmentKey)
        services = Self.makeServices(for: new)
        observeVersion()
        await launch()
    }
}
