import SwiftUI
import AuthenticationServices

private enum AccountScreenMode: Equatable {
    case signUp
    case signIn
    case testAccount
}

struct AccountScreen: View {
    @ObservedObject var authSession: AuthSession
    let appTheme: AppTheme
    let onClose: () -> Void
    @State private var mode = AccountScreenMode.signUp
    @State private var showAccountDeletion = false
    @State private var testEmail = "free-tier1@example.com"
    @State private var testPassword = ""
    @State private var isSubmittingTestLogin = false
    @State private var showUpgradeInfo = false

    private var panelColor: Color { appTheme.panelColor }
    private var inkColor: Color { appTheme.inkColor }
    private var accentColor: Color { appTheme.accentColor }
    private var cardColor: Color { appTheme.cardColor }

    var body: some View {
        Group {
            if authSession.isAuthenticated {
                accountManagementView
            } else {
                switch mode {
                case .signUp:
                    signUpView
                case .signIn:
                    signInView
                case .testAccount:
                    #if DEBUG
                    if AppConfig.serverURL.host == "localhost" { localTestAccountView }
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
        .task { if !authSession.isAuthenticated { await authSession.prepareAppleSignIn() } }
        .onChange(of: mode) { _, newMode in
            if !authSession.isAuthenticated && newMode != .testAccount {
                Task { await authSession.prepareAppleSignIn() }
            }
        }
        .confirmationDialog("Delete your Youki account?", isPresented: $showAccountDeletion) {
            Button("Delete account", role: .destructive) {
                Task {
                    await authSession.deleteAccount()
                    if !authSession.isAuthenticated { onClose() }
                }
            }
        } message: {
            Text("This removes your account and ends all sessions. Local alarms remain on this device.")
        }
        .sheet(isPresented: $showUpgradeInfo) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Youki Pro")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("A one-time upgrade is planned. Purchases are not available yet.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.65))
                Button("Done") { showUpgradeInfo = false }
                    .buttonStyle(.borderedProminent)
                    .tint(accentColor)
                Spacer()
            }
            .padding(26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(inkColor)
            .background(panelColor)
            .presentationDetents([.height(280)])
        }
    }

    private var accountManagementView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.horizon.fill")
                            .foregroundStyle(accentColor)
                        Text("youki")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Button("Done") { onClose() }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .accessibilityIdentifier("accountDoneButton")
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Your account")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Manage your profile and membership.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(inkColor.opacity(0.62))
                }

                accountIdentityCard
                membershipCard

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading("ACCOUNT")
                    Button {
                        mode = .signIn
                        Task {
                            await authSession.signOut()
                            await authSession.prepareAppleSignIn()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 17, weight: .medium))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Sign out")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("Return to the sign-in screen")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(inkColor.opacity(0.58))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(inkColor.opacity(0.38))
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                        .foregroundStyle(inkColor)
                    }
                    .buttonStyle(.plain)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("signOutButton")
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionHeading("DANGER ZONE")
                    Button(role: .destructive) { showAccountDeletion = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Delete account")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("Permanently remove your Youki account")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(inkColor.opacity(0.58))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(inkColor.opacity(0.38))
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                        .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .background(cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("deleteAccountButton")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
    }

    private var accountIdentityCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38))
                .symbolRenderingMode(.palette)
                .foregroundStyle(accentColor, accentColor.opacity(0.18))
            VStack(alignment: .leading, spacing: 4) {
                Text("SIGNED IN")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(inkColor.opacity(0.5))
                Text(authSession.account?.user.email ?? "Apple Account")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityIdentifier("accountEmail")
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(accentColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: authSession.account?.tier == "pro" ? "sparkles" : "sun.max.fill")
                Text(authSession.account?.tier == "pro" ? "YOUKI PRO" : "YOUKI FREE")
                    .tracking(1.2)
                Spacer()
                if authSession.account?.tier == "pro" {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.8)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(accentColor.opacity(0.16), in: Capsule())
                        .accessibilityIdentifier("proMembershipStatus")
                }
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(authSession.account?.tier == "pro" ? "Lifetime membership" : "Free membership")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(authSession.account?.tier == "pro"
                     ? "Your Youki Pro access is active on this account."
                     : "Live forecasts and golden-hour alarms are included.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(inkColor.opacity(0.66))
            }

            if authSession.account?.tier != "pro" {
                Button("Explore Youki Pro") { showUpgradeInfo = true }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .foregroundStyle(panelColor)
                    .background(accentColor, in: Capsule())
                    .accessibilityIdentifier("exploreProButton")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(appTheme == .dark ? 0.08 : 0.12),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accentColor.opacity(0.18), lineWidth: 1)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(inkColor.opacity(0.48))
            .padding(.leading, 3)
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
                if AppConfig.serverURL.host == "localhost" {
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

    #if DEBUG
    private var localTestAccountView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                accountHeader(backToSignIn: true)
                    .padding(.bottom, 24)
                Rectangle()
                    .fill(inkColor.opacity(0.14))
                    .frame(height: 1)
                    .padding(.bottom, 12)
                Text("LOCAL TEST ACCOUNTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(accentColor)
                Text("Preview Free and Pro access with a seeded local account.")
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
    #endif

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
            } else {
                Button("Done") { onClose() }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .accessibilityIdentifier("accountDoneButton")
            }
        }
    }

    @ViewBuilder
    private var authErrorMessage: some View {
        if let errorMessage = authSession.errorMessage {
            VStack(spacing: 8) {
                Text(errorMessage)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(accentColor)
                    .multilineTextAlignment(.center)
                if authSession.appleNonceHash == nil {
                    Button("Try again") { Task { await authSession.prepareAppleSignIn() } }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .accessibilityIdentifier("retryAppleSignInButton")
                }
            }
            .frame(maxWidth: .infinity)
        } else if authSession.appleNonceHash == nil {
            ProgressView("Preparing Apple sign-in")
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
            ProgressView("Preparing Apple sign-in")
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
