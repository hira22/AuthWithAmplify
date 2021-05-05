//
//  ContentView.swift
//  AuthWithAmplify
//
//  Created by hiraoka on 2021/05/05.
//

import AuthenticationServices
import SwiftUI
import Combine

import Amplify
import AWSCognitoAuthPlugin
import AWSMobileClientXCF

struct AppleUser: Codable {
    let userId: String
    let givenName: String
    let familyName: String
    let email: String

    init?(credentials: ASAuthorizationAppleIDCredential) {
        guard let givenName = credentials.fullName?.givenName,
              let familyName = credentials.fullName?.familyName,
              let email = credentials.email
        else { return nil }

        self.userId = credentials.user
        self.givenName = givenName
        self.familyName = familyName
        self.email = email
    }
}

enum AuthProvider: String {
    case signInWithApple
}


struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @State var authState: String = "none"

    @State var cancellables: Set<AnyCancellable> = []

    var body: some View {
        VStack {
            Text(authState)

            SignInWithAppleButton(.signIn, onRequest: onRequest, onCompletion: onCompletion)
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 45)
                .padding()
        }
        .onAppear(perform: attemptAutoAppleSignIn)
        .navigationBarItems(trailing: Button("sign out", action: signOut))
        .padding()
    }

    func onRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = ""

    }

    func onCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            switch auth.credential {
            case let appleIdCredentials as ASAuthorizationAppleIDCredential:
                if let appleUser = AppleUser(credentials: appleIdCredentials),
                   let appleUserData = try? JSONEncoder().encode(appleUser) {

                    UserDefaults.standard.setValue(appleUserData, forKey: appleUser.userId)

                    print(appleUser)
                } else {
                    guard let appleUserData = UserDefaults.standard.data(forKey: appleIdCredentials.user),
                          let appleUser = try? JSONDecoder().decode(AppleUser.self, from: appleUserData)
                    else { return }


                    print(appleUser)
                }
                signIn(with: appleIdCredentials.user)

            default:
                print(auth.credential)
            }
        case .failure(let error):
            print(error)
        }
    }

    private func signIn(with userId: String) {
        guard let plugin = try? Amplify.Auth.getPlugin(for: AWSCognitoAuthPlugin().key),
              let authPlugin = plugin as? AWSCognitoAuthPlugin,
              case .awsMobileClient(let client) = authPlugin.getEscapeHatch() else { return }
        client.federatedSignIn(providerName: AuthProvider.signInWithApple.rawValue,
                               token: userId) { (state: UserState?, error: Error?) in
            if let error = error {
                print(error)
                return
            }

            if let state = state {
                print("federatedSignIn: ", state)
                if case .signedIn = state {
                    authState = "signed in"
                }
            }
        }
    }

    func signOut() {
        Amplify.Auth.signOut()
            .resultPublisher
            .sink { completion in
                if case .failure(let error) = completion {
                    print(error)
                }
            } receiveValue: { _ in
                authState = "signed out"
            }
            .store(in: &cancellables)

    }

    private func attemptAutoAppleSignIn() {
        guard let plugin = try? Amplify.Auth.getPlugin(for: AWSCognitoAuthPlugin().key),
              let authPlugin = plugin as? AWSCognitoAuthPlugin,
              case .awsMobileClient(let client) = authPlugin.getEscapeHatch(),
              let logins = client.logins().result,
              let appleUserId = logins[AuthProvider.signInWithApple.rawValue] as? String
        else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserId) { (state: ASAuthorizationAppleIDProvider.CredentialState, error: Error?) in
            if let error = error {
                print(error)
                return
            }

            switch state {
            case .revoked:
                print("revoked")
            case .authorized:
                authState = "authorized"
            case .notFound:
                authState = "notFound"
            case .transferred:
                print("transferred")
            @unknown default:
                break
            }
        }

    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContentView()
        }
    }
}
