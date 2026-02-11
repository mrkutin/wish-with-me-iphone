import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityLabel("Wish With Me logo")

                    Text("Wish With Me")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Share your wishes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)

                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Email address")

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Password")
                }
                .padding(.horizontal)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await viewModel.login()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Log In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.brandPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Log in button")

                SocialLoginButtons()

                Spacer()

                NavigationLink {
                    RegisterView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(.secondary)
                        Text("Register")
                            .foregroundStyle(Color.brandPrimary)
                            .fontWeight(.semibold)
                    }
                }
                .accessibilityLabel("Go to registration")
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
