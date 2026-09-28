import SwiftUI

enum AccountScreenMode: Equatable {
    case signUp
    case signIn
    case testAccount
}

struct AccountScreen: View {
    @ObservedObject var authSession: AuthSession
    let appTheme: AppTheme
    let onClose: () -> Void
    @State private var entryMode = AccountScreenMode.signUp

    var body: some View {
        Group {
            if authSession.isAuthenticated {
                AccountManagementView(
                    authSession: authSession,
                    appTheme: appTheme,
                    onClose: onClose,
                    onSignOut: { entryMode = .signIn }
                )
            } else {
                AccountEntryView(
                    authSession: authSession,
                    appTheme: appTheme,
                    onClose: onClose,
                    initialMode: entryMode
                )
            }
        }
    }
}
