import SwiftUI
import AuthenticationServices

struct AccountEntryView: View {
    @ObservedObject var authSession: AuthSession
    let appTheme: AppTheme
    let onClose: () -> Void
    @State private var mode: AccountScreenMode
    @State private var testEmail = "free-tier1@example.com"
    @State private var testPassword = ""
    @State private var isSubmittingTestLogin = false

    private var panelColor: Color { appTheme.panelColor }
    private var inkColor: Color { appTheme.inkColor }
    private var accentColor: Color { appTheme.accentColor }
    private var cardColor: Color { appTheme.cardColor }

    init(
        authSession: AuthSession,
        appTheme: AppTheme,
        onClose: @escaping () -> Void,
        initialMode: AccountScreenMode
    ) {
        self.authSession = authSession
        self.appTheme = appTheme
        self.onClose = onClose
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        Group {
            if authSession.temporaryLoginEnabled {
                localTestAccountView
            } else {
                switch mode {
                case .signUp:
                    signUpView
                case .signIn:
                    signInView
                case .testAccount:
                    #if DEBUG
                    if ["localhost", "127.0.0.1"].contains(AppConfig.serverURL.host ?? "") {
                        localTestAccountView
                    }
                    else { signInView }
                    #else
                    signInView
                    #endif
                }
            }
        }
        .foregroundStyle(inkColor)
        .background(panelColor.ignoresSafeArea())
        .preferredColorScheme(appTheme.colorScheme)
        .task { await authSession.prepareSignIn() }
        .onChange(of: mode) { _, newMode in
            if newMode != .testAccount { Task { await authSession.prepareSignIn() } }
        }
    }

    private var signUpView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                accountHeader
                    .padding(.bottom, 24)

                accountSkyCard
                    .padding(.bottom, 26)

                Text("Your sky, every day.")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .padding(.bottom, 8)
                Text("Create a free account for your live sky forecast and golden-hour alerts.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 22)

                appleAuthButton(creatingAccount: true)

                Text("Your account starts on the Free tier. You can use the same Apple Account whenever you sign in.")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)

                authErrorMessage
                    .padding(.top, 12)

                Button {
                    mode = .signIn
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(inkColor.opacity(0.62))
                        Text("Sign in")
                            .fontWeight(.semibold)
                            .foregroundStyle(accentColor)
                    }
                    .font(.system(size: 13, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
                .accessibilityIdentifier("signInEntryLink")
            }
            .padding(.horizontal, 26)
            .padding(.top, 30)
            .padding(.bottom, 32)
        }
    }

    private var signInView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                accountHeader
                    .padding(.bottom, 58)

                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(accentColor)
                    .padding(.bottom, 18)
                Text("Welcome back.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .padding(.bottom, 10)
                Text("Sign in to see your live sky forecast and golden-hour alerts.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 32)

                appleAuthButton(creatingAccount: false)
                Text("Use the Apple Account you linked to Youki.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)

                authErrorMessage
                    .padding(.top, 12)

                Rectangle()
                    .fill(inkColor.opacity(0.12))
                    .frame(height: 1)
                    .padding(.top, 34)
                    .padding(.bottom, 22)

                Button {
                    mode = .signUp
                } label: {
                    HStack(spacing: 4) {
                        Text("New to Youki?")
                            .foregroundStyle(inkColor.opacity(0.62))
                        Text("Create a free account")
                            .fontWeight(.semibold)
                            .foregroundStyle(accentColor)
                    }
                    .font(.system(size: 13, design: .rounded))
                    .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("createAccountEntryLink")

                #if DEBUG
                if ["localhost", "127.0.0.1"].contains(AppConfig.serverURL.host ?? "") {
                    Button("Use a local test account") { mode = .testAccount }
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                        .accessibilityIdentifier("openTestAccountLink")
                }
                #endif
            }
            .padding(.horizontal, 26)
            .padding(.top, 30)
            .padding(.bottom, 36)
        }
    }

    private var localTestAccountView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                accountHeader(backToSignIn: !authSession.temporaryLoginEnabled)
                    .padding(.bottom, 24)
                Rectangle()
                    .fill(inkColor.opacity(0.14))
                    .frame(height: 1)
                    .padding(.bottom, 12)
                Text("Your sky, every day.")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Sign in to explore sunrise, sunset, and the colors ahead.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.68))
                    .padding(.bottom, 18)
                Text(authSession.temporaryLoginEnabled ? "TEST ACCOUNTS" : "LOCAL TEST ACCOUNTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(accentColor)
                Text("Sign in with a Free or Pro test account using the password provided to you.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.65))
                Menu {
                    ForEach(["free-tier1@example.com", "free-tier2@example.com",
                             "paid-tier1@example.com", "paid-tier2@example.com"], id: \.self) { email in
                        Button(email) { testEmail = email }
                    }
                } label: {
                    HStack {
                        Text(testEmail)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .padding(14)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityIdentifier("testAccountPicker")
                SecureField("Test password", text: $testPassword)
                    .textContentType(.password)
                    .padding(14)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("testAccountPassword")
                Button {
                    isSubmittingTestLogin = true
                    Task {
                        await authSession.signInLocalTestUser(email: testEmail, password: testPassword)
                        testPassword = ""
                        isSubmittingTestLogin = false
                    }
                } label: {
                    Text("Sign in to test account")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(panelColor)
                        .background(accentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(testPassword.isEmpty || isSubmittingTestLogin)
                .accessibilityIdentifier("testAccountSignInButton")
                authErrorMessage
                    .padding(.top, 8)
            }
            .padding(.horizontal, 26)
            .padding(.top, 30)
            .padding(.bottom, 36)
        }
    }

    private var accountHeader: some View {
        accountHeader(backToSignIn: false)
    }

    private func accountHeader(backToSignIn: Bool) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(accentColor)
                Text("youki")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            Spacer()
            if backToSignIn {
                Button("Back") { mode = .signIn }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            } else if authSession.isAuthenticated {
                Button("Close") { onClose() }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .accessibilityIdentifier("accountDoneButton")
            }
        }
    }

    @ViewBuilder
    private var authErrorMessage: some View {
        if let errorMessage = authSession.errorMessage {
            VStack(spacing: 8) {
                Text(AppLocalization.text(errorMessage))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(accentColor)
                    .multilineTextAlignment(.center)
                if authSession.appleNonceHash == nil && !authSession.temporaryLoginEnabled {
                    Button("Try again") { Task { await authSession.prepareSignIn() } }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("retryAppleSignInButton")
                }
            }
            .frame(maxWidth: .infinity)
        } else if authSession.appleNonceHash == nil && !authSession.temporaryLoginEnabled {
            ProgressView("Preparing sign-in")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    @ViewBuilder
    private func appleAuthButton(creatingAccount: Bool) -> some View {
        if let nonceHash = authSession.appleNonceHash {
            SignInWithAppleButton(creatingAccount ? .signUp : .signIn, onRequest: { request in
                request.requestedScopes = []
                request.nonce = nonceHash
            }, onCompletion: { result in
                Task { await authSession.completeAppleSignIn(result) }
            })
            .signInWithAppleButtonStyle(appTheme == .dark ? .white : .black)
            .frame(height: 54)
            .id(creatingAccount)
            .accessibilityIdentifier("appleSignInButton")
        } else {
            ProgressView("Preparing sign-in")
                .frame(maxWidth: .infinity, minHeight: 54)
        }
    }

    private var accountSkyCard: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: "#30364C"), Color(hex: "#735565"), Color(hex: "#D98962"), Color(hex: "#F0B968")],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(Color(hex: "#FFE3A6"))
                .frame(width: 114, height: 114)
                .blur(radius: 4)
                .offset(x: 188, y: 50)
            VStack(alignment: .leading, spacing: 5) {
                Text("MAKE ROOM FOR WONDER")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(2)
                Text("Never miss the\ngood light.")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .lineSpacing(0)
            }
            .foregroundStyle(.white)
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 178)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

}
