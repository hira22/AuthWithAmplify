//
//  AuthWithAmplifyApp.swift
//  AuthWithAmplify
//
//  Created by hiraoka on 2021/05/05.
//

import SwiftUI
import Amplify
import AWSCognitoAuthPlugin
import AuthenticationServices

@main
struct AuthWithAmplifyApp: App {

    init() {
        configureAmplify()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }
    }

    private func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()

        } catch {
            print(error)
        }
    }
}
