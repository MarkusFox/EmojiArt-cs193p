//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Markus Fox on 07.01.22.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    let document = EmojiArtDocument()
    
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: document)
        }
    }
}
