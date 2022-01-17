//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Markus Fox on 07.01.22.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    @StateObject var paletteStore = PaletteStore(named: "default")
    
    var body: some Scene {
        DocumentGroup(newDocument: { EmojiArtDocument() } ) { config in
            EmojiArtDocumentView(document: config.document)
                .environmentObject(paletteStore)
        }
    }
}
