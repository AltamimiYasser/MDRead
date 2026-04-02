//
//  AppearanceManager.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

@Observable
class AppearanceManager {
    enum Mode: String, CaseIterable {
        case auto, light, dark

        var label: String {
            switch self {
            case .auto: "Auto"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        var icon: String {
            switch self {
            case .auto: "circle.lefthalf.filled"
            case .light: "sun.max"
            case .dark: "moon"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .auto: nil
            case .light: .light
            case .dark: .dark
            }
        }

        var cssValue: String {
            rawValue
        }
    }

    var mode: Mode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode")
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appearanceMode") ?? "auto"
        mode = Mode(rawValue: raw) ?? .auto
    }
}
