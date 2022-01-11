//
//  ContentView.swift
//  EmojiArt
//
//  Created by Markus Fox on 07.01.22.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    let defaultEmojiFontSize: CGFloat = 40
    
    var body: some View {
        VStack(spacing: 0) {
            documentBody
            palette
        }
    }
    
    var documentBody: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white.overlay(
                    OptionalImage(uiImage: document.backgroundImage)
                        .scaleEffect(zoomScale)
                        .position(convertFromEmojiCoordinates((0,0), in: geometry))
                )
                    .gesture(doubleTapToZoom(in: geometry.size))
                    .onTapGesture {
                        selectedEmojis = []
                    }
                if document.backgroundImageFetchStatus == .fetching {
                    ProgressView().scaleEffect(2)
                } else {
                    ForEach(document.emojis) { emoji in
                        Text(emoji.text)
                            .font(.system(size: fontSize(for: emoji)))
                            .scaleEffect(emojiZoomScale(for: emoji))
                            .position(position(for: emoji, in: geometry))
                            .offset(emojiIsSelected(emoji) ? emojiOffset : CGSize.zero)
                            .onTapGesture {
                                selectedEmojis.toggleMembership(of: emoji)
                            }
                            .gesture(emojiIsSelected(emoji) ? dragSelectedEmojis(from: emoji) : nil)
                            .shadow(color: emojiIsSelected(emoji) ? .red : .clear, radius: 10)
                    }
                }
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            deleteSelectedEmojis()
                        }, label: {
                            Image(systemName: hasSelection ? "trash" : "trash.slash")
                                .font(.largeTitle)
                                .shadow(color: Color.blue, radius: 10)
                                .padding()
                        })
                    }
                    Spacer()
                }
            }
            .clipped()
            .onReceive(document.$backgroundImage) { image in
                withAnimation {
                    zoomToFit(image, in: geometry.size)
                }
            }
            .onDrop(of: [.plainText, .url, .image], isTargeted: nil) { providers, location in
                return drop(providers: providers, at: location, in: geometry)
            }
            .gesture(panGesture().simultaneously(with: zoomGesture()))
        }
    }
    
    private func deleteSelectedEmojis() {
        for selectedEmoji in selectedEmojis {
            document.removeEmoji(selectedEmoji)
        }
        selectedEmojis = []
    }
    
    @GestureState private var gestureEmojiOffset: CGSize = .zero
    private var emojiOffset: CGSize {
        gestureEmojiOffset * zoomScale // UtilityExtension to CGSize
    }
    
    private func dragSelectedEmojis(from emoji: EmojiArtModel.Emoji) -> some Gesture {
        let draggedEmojiIsSelected = emojiIsSelected(emoji)
        return DragGesture()
            .updating($gestureEmojiOffset) { latestDragGestureValue, gestureEmojiOffset, _ in
                if draggedEmojiIsSelected {
                    gestureEmojiOffset = latestDragGestureValue.translation / zoomScale
                }
            }
            .onEnded { finalDragGestureValue in
                let offset = finalDragGestureValue.translation / zoomScale
                if draggedEmojiIsSelected {
                    for selectedEmoji in selectedEmojis {
                        document.moveEmoji(selectedEmoji, by: offset)
                    }
                }
                selectedEmojis = []
            }
    }
    
    @State private var selectedEmojis: Set<EmojiArtModel.Emoji> = []
    
    private var hasSelection: Bool {
        !selectedEmojis.isEmpty
    }
    
    private func emojiIsSelected(_ emoji: EmojiArtModel.Emoji) -> Bool {
        return selectedEmojis.contains(emoji)
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint, in geometry: GeometryProxy) -> Bool {
        var found = providers.loadObjects(ofType: URL.self) { url in
            document.setBackground(EmojiArtModel.Background.url(url.imageURL))
        }
        if !found {
            found = providers.loadObjects(ofType: UIImage.self) { image in
                if let data = image.jpegData(compressionQuality: 1.0) {
                    document.setBackground(.imageData(data))
                }
            }
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                if let emoji = string.first, emoji.isEmoji {
                    document.addEmoji(
                        String(emoji),
                        at: convertToEmojiCoordinates(location, in: geometry),
                        size: defaultEmojiFontSize / zoomScale
                    )
                }
            }
        }
        return found
    }
    
    private func position(for emoji: EmojiArtModel.Emoji, in geometry: GeometryProxy) -> CGPoint {
        convertFromEmojiCoordinates((emoji.x, emoji.y), in: geometry)
    }
    
    private func convertToEmojiCoordinates(_ location: CGPoint, in geometry: GeometryProxy) -> (x: Int, y: Int) {
        let center = geometry.frame(in: .local).center
        let location = CGPoint(
            x: (location.x - panOffset.width - center.x)  / zoomScale,
            y: (location.y - panOffset.height - center.y)  / zoomScale
        )
        return (Int(location.x), Int(location.y))
    }
    private func convertFromEmojiCoordinates(_ location: (x: Int, y: Int), in geometry: GeometryProxy) -> CGPoint {
        let center = geometry.frame(in: .local).center
        return CGPoint (
            x: center.x + CGFloat(location.x) * zoomScale + panOffset.width,
            y: center.y + CGFloat(location.y) * zoomScale + panOffset.height
        )
    }
    
    private func fontSize(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        CGFloat(emoji.size)
    }
    
    @State private var steadyStatePanOffset: CGSize = CGSize.zero
    @GestureState private var gesturePanOffset: CGSize = CGSize.zero
    
    private var panOffset: CGSize {
        (steadyStatePanOffset + gesturePanOffset) * zoomScale // UtilityExtension to CGSize
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffsetInOut, _ in
                gesturePanOffsetInOut = latestDragGestureValue.translation / zoomScale
            }
            .onEnded { finalDragGestureValue in
                steadyStatePanOffset = steadyStatePanOffset + (finalDragGestureValue.translation / zoomScale)
            }
    }
    
    @State private var steadyStateZoomScale: CGFloat = 1
    @GestureState private var gestureZoomScale: CGFloat = 1 // extra credit ass5 this might be tuple or struct
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * (hasSelection ? 1 : gestureZoomScale)
    }
    
    private func emojiZoomScale(for emoji: EmojiArtModel.Emoji) -> CGFloat {
        if emojiIsSelected(emoji) {
            return steadyStateZoomScale * gestureZoomScale
        } else {
            return zoomScale
        }
    }
    
    private func zoomGesture() -> some Gesture {
        MagnificationGesture()
            .updating($gestureZoomScale) { latestGestureScale, ourGestureStateInOut, transaction in
                ourGestureStateInOut = latestGestureScale
            }
            .onEnded { gestureScaleAtEnd in
                if hasSelection {
                    for selectedEmoji in selectedEmojis {
                        document.scaleEmoji(selectedEmoji, by: gestureScaleAtEnd)
                    }
                    selectedEmojis = []
                } else {
                    steadyStateZoomScale *= gestureScaleAtEnd
                }
            }
    }
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    zoomToFit(document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 {
            let hZoom = size.width / image.size.width
            let vZoom = size.height / image.size.height
            steadyStatePanOffset = .zero
            steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    var palette: some View {
        ScrollingEmojisView(emojis: testemojis)
            .font(.system(size: defaultEmojiFontSize))
    }
    
    let testemojis = "☹️😱✍️👷🧛‍♀️💧💥☄️"
}

struct ScrollingEmojisView: View {
    let emojis: String
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(emojis.map { String($0) }, id: \.self) { emoji in
                    Text(emoji)
                        .onDrag { NSItemProvider(object: emoji as NSString) }
                }
            }
        }
    }
}
