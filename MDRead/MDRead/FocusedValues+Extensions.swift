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

// MARK: - Search Action

struct SearchActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var searchAction: (() -> Void)? {
        get { self[SearchActionKey.self] }
        set { self[SearchActionKey.self] = newValue }
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

// MARK: - Save Action

struct SaveActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct CanSaveDocumentKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var saveAction: (() -> Void)? {
        get { self[SaveActionKey.self] }
        set { self[SaveActionKey.self] = newValue }
    }

    var canSaveDocument: Bool? {
        get { self[CanSaveDocumentKey.self] }
        set { self[CanSaveDocumentKey.self] = newValue }
    }
}
