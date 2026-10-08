import SwiftUI

struct AccountManagementView: View {
    @ObservedObject var authSession: AuthSession
    let appTheme: AppTheme
    let onClose: () -> Void
    let onSignOut: () -> Void
    @State private var showAccountDeletion = false
    @State private var showUpgradeInfo = false

    private var panelColor: Color { appTheme.panelColor }
    private var inkColor: Color { appTheme.inkColor }
    private var accentColor: Color { appTheme.accentColor }
    private var cardColor: Color { appTheme.cardColor }

    var body: some View {
        accountManagementView
            .foregroundStyle(inkColor)
            .background(panelColor.ignoresSafeArea())
            .preferredColorScheme(appTheme.colorScheme)
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
                    Button("Close") { showUpgradeInfo = false }
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
                    Button("Close") { onClose() }
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
                        onSignOut()
                        Task {
                            await authSession.signOut()
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
        let isPro = authSession.account?.tier == "pro"
        return ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(hex: "#34394E"), Color(hex: "#70566A"), Color(hex: "#C87962"), Color(hex: "#EBAF68")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "#FFE5A8").opacity(0.85))
                .frame(width: 116, height: 116)
                .blur(radius: 2)
                .offset(x: 28, y: 28)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label(isPro ? "YOUKI PRO" : "YOUKI MEMBERSHIP",
                          systemImage: isPro ? "sparkles" : "sun.max.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                    Spacer()
                    if isPro {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.18), in: Capsule())
                            .accessibilityIdentifier("proMembershipStatus")
                    }
                }
                .foregroundStyle(.white.opacity(0.94))

                Spacer(minLength: 20)

                Text(isPro ? "Lifetime membership" : "Free membership")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(isPro
                     ? "Your Youki Pro access is active on this account."
                     : "Live forecasts and golden-hour alarms are included.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.top, 5)

                if !isPro {
                    Button("Explore Youki Pro") { showUpgradeInfo = true }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(Color(hex: "#493B3B"))
                        .background(.white.opacity(0.92), in: Capsule())
                        .padding(.top, 14)
                        .accessibilityIdentifier("exploreProButton")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: isPro ? 174 : 206, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func sectionHeading(_ title: String) -> some View {
                Text(AppLocalization.text(title))
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.3)
            .foregroundStyle(inkColor.opacity(0.48))
            .padding(.leading, 3)
    }

}
