//
//  MDReadDocument.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct MDReadDocument: FileDocument {
    var text: String

    init(text: String = "") {
        self.text = text
    }

    static let readableContentTypes: [UTType] = [
        UTType(filenameExtension: "md"),
        UTType(filenameExtension: "markdown"),
        UTType(filenameExtension: "mdown"),
        UTType(filenameExtension: "mkdn"),
        UTType(filenameExtension: "mkd"),
        UTType(filenameExtension: "mdx"),
    ].compactMap { $0 }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    // Required by FileDocument but we don't need write support
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}
