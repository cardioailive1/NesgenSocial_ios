import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: AuthSession
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("NexgenSocial")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Text("A social platform that shows its working")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.slate400)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)

                    if isSignUp { SignUpForm() } else { SignInForm() }

                    Button {
                        withAnimation { isSignUp.toggle() }
                        session.errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in"
                                      : "New here? Create an account")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.cyan300)
                    }

                    if isSignUp { HighlightsSection() }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.navy950)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

struct SignInForm: View {
    @EnvironmentObject var session: AuthSession
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var showForgotPassword = false

    var body: some View {
        VStack(spacing: 12) {
            // Not .emailAddress: the server accepts a username here too, and
            // the email keyboard makes a username needlessly awkward to type.
            TextField("Email or username", text: $email)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            SecureField("Password", text: $password)
                .textContentType(.password)
                .fieldStyle()

            ErrorBanner(message: session.errorMessage)

            Button {
                busy = true
                Task {
                    await session.signIn(emailOrUsername: email, password: password)
                    busy = false
                }
            } label: {
                Text(busy ? "Signing in…" : "Sign in").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy || email.isEmpty || password.isEmpty)

            Button("Forgot your password?") {
                session.errorMessage = nil
                showForgotPassword = true
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.cyan300)
        }
        .padding(18)
        .card()
        .sheet(isPresented: $showForgotPassword) { ForgotPasswordView() }
    }
}

/// Requests the reset email, then finishes the reset in the app: the token
/// lives in the emailed link, so pasting that link is enough — no round trip
/// through the browser.
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var busy = false
    @State private var sent = false
    @State private var showReset = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    if sent {
                        Text("If an account exists for \(email), we've sent a link to choose a new password. It expires in an hour.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.slate300)
                        Text("Nothing arrived? Check your spam folder, and make sure you used the address you signed up with. Delivery can take a couple of minutes.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)

                        Divider().overlay(Theme.slate400.opacity(0.3))

                        Text("Got the email? Copy the link and paste it here to set your new password without leaving the app.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.slate300)
                        Button("Paste reset link") { showReset = true }
                            .buttonStyle(PrimaryButtonStyle())

                        Button("Back to sign in") { dismiss() }
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.cyan300)
                    } else {
                        Text("Enter the email address on your account and we'll send you a link to set a new password.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)

                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .fieldStyle()

                        ErrorBanner(message: errorMessage)

                        Button {
                            Task { await send() }
                        } label: {
                            Text(busy ? "Sending…" : "Send reset link").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(busy || !email.contains("@"))
                    }
                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("Reset your password")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
            }
            .sheet(isPresented: $showReset) {
                ChooseNewPasswordView { dismiss() }
            }
        }
    }

    private func send() async {
        busy = true
        defer { busy = false }
        do {
            try await AuthService.forgotPassword(email: email.trimmingCharacters(in: .whitespaces))
            errorMessage = nil
            sent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Second half of the reset: paste the emailed link, then choose the password.
/// The token is checked before the form appears so an expired link says so
/// straight away.
struct ChooseNewPasswordView: View {
    /// Called after a successful change, to close the forgot-password sheet too.
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pasted = ""
    @State private var token: String?
    @State private var password = ""
    @State private var confirm = ""
    @State private var busy = false
    @State private var done = false
    @State private var errorMessage: String?

    private var passwordProblem: String? {
        if password.count < 8 { return "Use at least 8 characters." }
        if password != confirm { return "The two passwords don't match." }
        return nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.navy950.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 12) {
                    if done {
                        Text("Your password has been changed. Sign in with it.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.cyan300)
                        Button("Back to sign in") { dismiss(); onFinished() }
                            .buttonStyle(PrimaryButtonStyle())
                    } else if let token {
                        Text("Choose a new password.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)

                        SecureField("New password (8+ characters)", text: $password)
                            .textContentType(.newPassword)
                            .fieldStyle()
                        SecureField("Confirm new password", text: $confirm)
                            .textContentType(.newPassword)
                            .fieldStyle()

                        if !confirm.isEmpty, let problem = passwordProblem {
                            Text(problem)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.danger)
                        }
                        ErrorBanner(message: errorMessage)

                        Button {
                            Task { await save(token: token) }
                        } label: {
                            Text(busy ? "Saving…" : "Change password").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(busy || passwordProblem != nil)
                    } else {
                        Text("Paste the link from the reset email. It expires an hour after it was sent and works once.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.slate400)

                        TextField("https://…/reset-password?token=…", text: $pasted, axis: .vertical)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .lineLimit(1...3)
                            .fieldStyle()

                        ErrorBanner(message: errorMessage)

                        Button {
                            Task { await check() }
                        } label: {
                            Text(busy ? "Checking…" : "Continue").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(busy || AuthService.resetToken(in: pasted) == nil)
                    }
                    Spacer()
                }
                .padding(18)
            }
            .navigationTitle("New password")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cyan400)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Theme.slate400)
                }
            }
        }
    }

    private func check() async {
        guard let candidate = AuthService.resetToken(in: pasted) else { return }
        busy = true
        defer { busy = false }
        do {
            if try await AuthService.resetTokenIsValid(candidate) {
                errorMessage = nil
                token = candidate
            } else {
                errorMessage = "That link has expired or has already been used. Request a fresh one."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(token: String) async {
        busy = true
        defer { busy = false }
        do {
            try await AuthService.resetPassword(token: token, password: password)
            errorMessage = nil
            done = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SignUpForm: View {
    @EnvironmentObject var session: AuthSession
    @State private var email = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var password = ""
    @State private var acceptedTerms = false
    @State private var busy = false

    // Mirrors the server's rule exactly. Catching it here means a clear
    // inline message instead of a round-trip that returns a 400.
    private var usernameValid: Bool {
        username.range(of: "^[a-zA-Z0-9_.-]{3,30}$", options: .regularExpression) != nil
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .fieldStyle()

            VStack(alignment: .leading, spacing: 4) {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fieldStyle()
                if !username.isEmpty && !usernameValid {
                    Text("Letters, numbers, and _ . - only. No spaces.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.danger)
                }
            }

            TextField("Display name", text: $displayName).fieldStyle()

            SecureField("Password (8+ characters)", text: $password)
                .textContentType(.newPassword)
                .fieldStyle()

            Toggle(isOn: $acceptedTerms) {
                Text("I agree to the Terms of Use and Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.slate300)
            }
            .tint(Theme.cyan400)

            HStack(spacing: 14) {
                Link("Terms", destination: URL(string: AppConfig.termsURL)!)
                Link("Privacy", destination: URL(string: AppConfig.privacyURL)!)
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.cyan300)
            .frame(maxWidth: .infinity, alignment: .leading)

            ErrorBanner(message: session.errorMessage)

            Button {
                busy = true
                Task {
                    await session.signUp(email: email, username: username,
                                         displayName: displayName, password: password,
                                         acceptedTerms: acceptedTerms)
                    busy = false
                }
            } label: {
                Text(busy ? "Creating…" : "Create account").frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(busy || !acceptedTerms || !usernameValid
                      || email.isEmpty || displayName.isEmpty || password.count < 8)
        }
        .padding(18)
        .card()
    }
}

/// The same highlights shown on the web signup page.
struct HighlightsSection: View {
    private let items: [(String, String, String)] = [
        ("play.rectangle.fill", "Reels that reach beyond your followers",
         "Reels rank on whether people watch to the end, not on follower count."),
        ("slider.horizontal.3", "Your feed, your rules",
         "Set how your feed weights recency, engagement and diversity."),
        ("lock.shield.fill", "Ad settings off by default",
         "Interest targeting is opt-in. We never sell your profile."),
        ("phone.fill", "Messages, voice and video calls",
         "Talk to anyone on NexgenSocial from anywhere with internet."),
        ("video.fill", "NexgenMeet",
         "Video meetings with waiting rooms and host controls."),
        ("bag.fill", "Marketplace and jobs",
         "Real photo and video listings; salary ranges shown up front."),
        ("square.and.arrow.up", "Take your data with you",
         "Export everything you've posted in one tap."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What you get")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            ForEach(items, id: \.1) { icon, title, body in
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.cyan400)
                        .frame(width: 30, height: 30)
                        .background(Theme.navy800)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(body)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.slate400)
                    }
                }
            }
        }
        .padding(18)
        .card()
    }
}

extension View {
    func fieldStyle() -> some View {
        self
            .font(.system(size: 15))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Theme.navy950)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }
}
