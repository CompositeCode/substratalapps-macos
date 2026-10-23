import SwiftUI
import SubstratalKit

/// AUTH-01 Sign in → AUTH-02 Two-factor challenge.
///
/// The spec puts these in a separate fixed-size `Window` that hides the main
/// windows; the skeleton shows them in the main window instead. See the
/// "Known gaps" section of the README.
struct SignInFlowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    @State private var email = ""
    @State private var password = ""
    @State private var testMode = false
    @State private var mfa: (token: String, methods: [String])?
    @State private var code = ""
    @State private var useRecoveryCode = false
    @State private var working = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 24) {
            Image("Brand/BrandLockup")
                .resizable()
                .scaledToFit()
                .frame(height: 56)
                .accessibilityLabel("Substratal Apps")

            Group {
                if let mfa {
                    mfaForm(token: mfa.token)
                } else {
                    signInForm
                }
            }
            .frame(width: 360)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .frame(width: 340, alignment: .leading)
            }

            HStack(spacing: 4) {
                Text("API:")
                Text(model.environment.displayName)
                Text("·")
                Button("Change in Settings…") { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) }
                    .buttonStyle(.link)
            }
            .font(.caption)
            .foregroundStyle(palette.textSecondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .disabled(working)
    }

    private var signInForm: some View {
        Form {
            TextField("Email", text: $email, prompt: Text("you@example.com"))
                .textContentType(.username)
            SecureField("Password", text: $password, prompt: Text("Required"))
                .textContentType(.password)
            if model.environment != .production {
                Toggle("Test-mode account", isOn: $testMode)
            }
            HStack {
                Button("Forgot password?") { openURL(URL(string: "https://dashboard.substratalapps.com/forgot-password")!) }
                    .buttonStyle(.link)
                Spacer()
                Button("Sign In") { Task { await signIn() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(email.isEmpty || password.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private func mfaForm(token: String) -> some View {
        Form {
            Text(useRecoveryCode ? "Enter one of your recovery codes." : "Enter the 6-digit code from your authenticator app.")
            TextField(useRecoveryCode ? "Recovery code" : "Code", text: $code)
                .textContentType(.oneTimeCode)
                .font(.body.monospaced())
            HStack {
                Button(useRecoveryCode ? "Use authenticator code" : "Use a recovery code") {
                    useRecoveryCode.toggle()
                    code = ""
                }
                .buttonStyle(.link)
                Spacer()
                Button("Back") { mfa = nil; code = "" }
                Button("Verify") { Task { await verify(token: token) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(code.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    private func signIn() async {
        working = true
        errorText = nil
        defer { working = false }
        do {
            switch try await model.signIn(email: email, password: password, testMode: testMode) {
            case .signedIn:
                password = ""
            case .mfaRequired(let token, let methods, _):
                mfa = (token, methods)
            }
        } catch {
            errorText = SignInCopy.message(for: error)
        }
    }

    private func verify(token: String) async {
        working = true
        errorText = nil
        defer { working = false }
        do {
            try await model.verifyMFA(
                mfaToken: token,
                code: useRecoveryCode ? nil : code,
                recoveryCode: useRecoveryCode ? code : nil
            )
        } catch {
            errorText = SignInCopy.message(for: error)
        }
    }
}

/// Copy for sign-in errors (COPY-AND-STATES).
enum SignInCopy {
    static func message(for error: Error) -> String {
        if APIProblem.isConnectivity(error) {
            return "Couldn't reach Substratal. Check your connection and try again."
        }
        guard let problem = error as? APIProblem else {
            // Not a network or API error: say what it was, so it can be reported.
            Log.app.error("sign-in failed: \(String(describing: error), privacy: .public)")
            return "Something went wrong signing in (\(String(describing: type(of: error))))."
        }
        switch problem.code {
        case "invalid_credentials": return "That email and password don't match."
        case "account_locked": return "Too many attempts. Try again in a few minutes."
        case "account_suspended", "user_suspended": return "This account is suspended. Contact support."
        case "test_user_expired": return "This test account has expired."
        case "invalid_mfa_code": return "That code didn't work. Check it and try again."
        case "mfa_token_expired": return "That took too long. Sign in again."
        case "rate_limited": return "Too many attempts. Wait a minute and try again."
        default: return problem.message
        }
    }
}
