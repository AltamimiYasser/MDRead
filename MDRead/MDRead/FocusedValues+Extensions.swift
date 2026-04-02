//
//  FocusedValues+Extensions.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

// MARK: - Font Size

struct FontSizeKey: FocusedValueKey {
    typealias Value = Binding<Double>
}

extension FocusedValues {
    var fontSize: Binding<Double>? {
        get { self[FontSizeKey.self] }
        set { self[FontSizeKey.self] = newValue }
    }
}

// MARK: - Print Action

struct PrintActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var printAction: (() -> Void)? {
        get { self[PrintActionKey.self] }
        set { self[PrintActionKey.self] = newValue }
    }
}

// MARK: - PDF Export Action

struct ExportPDFActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var exportPDFAction: (() -> Void)? {
        get { self[ExportPDFActionKey.self] }
        set { self[ExportPDFActionKey.self] = newValue }
    }
}
