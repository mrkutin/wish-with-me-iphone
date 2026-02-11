import SwiftUI

struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 50))
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityLabel("Create account icon")

                Text("Create Account")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Join Wish With Me")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 16)

            VStack(spacing: 16) {
                TextField("Name", text: $viewModel.name)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Your name")

                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Email address")

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Password")

                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Confirm password")
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
                    await viewModel.register()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text("Register")
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
            .accessibilityLabel("Register button")

            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
