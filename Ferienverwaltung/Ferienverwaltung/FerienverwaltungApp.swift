//
//  FerienverwaltungApp.swift
//  Ferienverwaltung
//
//  Created by Michael Schellenberger on 02.04.25.
//

import SwiftUI

@main
struct FerienverwaltungApp: App {
    @StateObject var viewModel = VacationViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
