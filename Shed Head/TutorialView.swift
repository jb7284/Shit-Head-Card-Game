import SwiftUI

struct TutorialSheet: View {
    let onFinish: () -> Void
    let onStartTutorialMode: () -> Void

    @State private var selectedStep = 0

    private let steps = TutorialStep.all

    var body: some View {
        ZStack {
            Image("playing_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.52).ignoresSafeArea())

            GeometryReader { geo in
                tutorialContent(safeAreaInsets: geo.safeAreaInsets)
                    .frame(width: geo.size.width, height: geo.size.height)
                .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func tutorialContent(safeAreaInsets: EdgeInsets) -> some View {
        #if os(iOS)
        TabView(selection: $selectedStep) {
            ForEach(steps.indices, id: \.self) { index in
                TutorialPage(
                    step: steps[index],
                    showsReturnButton: index > 0,
                    showsStartButton: index == steps.count - 1,
                    pageCount: steps.count,
                    selectedStep: selectedStep,
                    safeAreaInsets: safeAreaInsets,
                    onSelectPage: { selectedStep = $0 },
                    onFinish: onFinish,
                    onStartTutorialMode: onStartTutorialMode
                )
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        #else
        TutorialPage(
            step: steps[selectedStep],
            showsReturnButton: selectedStep > 0,
            showsStartButton: selectedStep == steps.count - 1,
            pageCount: steps.count,
            selectedStep: selectedStep,
            safeAreaInsets: safeAreaInsets,
            onSelectPage: { selectedStep = $0 },
            onFinish: onFinish,
            onStartTutorialMode: onStartTutorialMode
        )
        #endif
    }
}

private struct TutorialPage: View {
    let step: TutorialStep
    let showsReturnButton: Bool
    let showsStartButton: Bool
    let pageCount: Int
    let selectedStep: Int
    let safeAreaInsets: EdgeInsets
    let onSelectPage: (Int) -> Void
    let onFinish: () -> Void
    let onStartTutorialMode: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 11) {
                Spacer(minLength: 0)

                step.visual
                    .frame(height: step.visualHeight)
                    .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Text(step.title)
                        .font(.system(size: 23, weight: .black, design: .serif))
                        .multilineTextAlignment(.center)

                    Text(step.message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 540)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, safeAreaInsets.leading + safeAreaInsets.trailing + 22)
            .padding(.bottom, showsStartButton ? 120 : 92)

            footer
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.leading, safeAreaInsets.leading + 16)
                .padding(.trailing, safeAreaInsets.trailing + 16)
                .padding(.bottom, max(58, safeAreaInsets.bottom + 58))
        }
    }

    private var returnButton: some View {
        Button {
            onFinish()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                Text("Return to Menu")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.92))
            .frame(height: 32)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.50))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if showsReturnButton {
                    returnButton
                }

                if showsStartButton {
                    Button {
                        onStartTutorialMode()
                    } label: {
                        HStack(spacing: 7) {
                            Text("Start Tutorial Mode")
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(height: 38)
                        .padding(.horizontal, 18)
                    }
                    .buttonStyle(TutorialControlButtonStyle(prominent: true))
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onSelectPage(index)
                        }
                    } label: {
                        Capsule()
                            .fill(index == selectedStep ? Color.goldAccent : Color.white.opacity(0.24))
                            .frame(width: index == selectedStep ? 18 : 8, height: 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TutorialPageContent: View {
    let step: TutorialStep

    var body: some View {
        VStack(spacing: 11) {
            Spacer(minLength: 0)

            step.visual
                .frame(height: step.visualHeight)
                .frame(maxWidth: .infinity)

            VStack(spacing: 6) {
                Text(step.title)
                    .font(.system(size: 23, weight: .black, design: .serif))
                    .multilineTextAlignment(.center)

                Text(step.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 540)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TutorialCalloutRow: View {
    let callout: TutorialCallout

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: callout.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.goldAccent)
                .frame(width: 23, height: 23)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.09)))

            VStack(alignment: .leading, spacing: 1) {
                Text(callout.title)
                    .font(.system(size: 13, weight: .bold))
                Text(callout.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct TutorialStep {
    let title: String
    let message: String
    let callouts: [TutorialCallout]
    let visualHeight: CGFloat
    let visual: AnyView

    static let all: [TutorialStep] = [
        TutorialStep(
            title: "The Goal",
            message: "Get rid of all your cards first, but definitely don't be last. Start with the cards in your hand. Once a player's draw pile and hand are empty, that player moves to face-up table cards. Face-down table cards are last: they stay hidden until you try one. If it can play, it moves to the center pile. If not, that card and the center pile move into your hand.",
            callouts: [
                TutorialCallout(icon: "rectangle.portrait.on.rectangle.portrait.fill", title: "Face-up table cards", detail: "These are played after all draw piles and hands are gone."),
                TutorialCallout(icon: "questionmark.square.fill", title: "Face-down table cards", detail: "These stay hidden until you try them. If the card can play, it moves to the center pile. If not, that card and the center pile move into your hand.")
            ],
            visualHeight: 118,
            visual: AnyView(TutorialZoneVisual())
        ),
        TutorialStep(
            title: "Swap Before You Play",
            message: "Before the game starts, you can improve your face-up table cards by swapping them with cards from your hand.",
            callouts: [
                TutorialCallout(icon: "arrow.left.arrow.right", title: "Choose your best table cards", detail: "Tap a hand card and a face-up table card to swap them."),
                TutorialCallout(icon: "checkmark.circle.fill", title: "Then start playing", detail: "When you are happy with your swaps, tap Ready to begin the game.")
            ],
            visualHeight: 130,
            visual: AnyView(TutorialSwapVisual())
        ),
        TutorialStep(
            title: "Play On The Pile",
            message: "Most turns are simple: play a card that is the same rank or higher than the top card on the pile. If you pick a card that is too low, it shakes so you know it cannot be played.",
            callouts: [
                TutorialCallout(icon: "arrow.up.circle.fill", title: "Same or higher works", detail: "A queen can play on a nine. Another nine can also play on a nine."),
                TutorialCallout(icon: "exclamationmark.triangle.fill", title: "Too low will shake", detail: "If a card is not legal, the game gives you a quick shake so you know it did not play.")
            ],
            visualHeight: 118,
            visual: AnyView(TutorialBeatPileVisual())
        ),
        TutorialStep(
            title: "How To Play Cards",
            message: "Double tap a card to play it quickly, or drag it toward the center pile and let go.",
            callouts: [
                TutorialCallout(icon: "hand.tap.fill", title: "Double tap", detail: "Fastest way to play one card."),
                TutorialCallout(icon: "arrow.up.to.line.compact", title: "Drag and drop", detail: "Drag a card toward the pile if that feels more natural.")
            ],
            visualHeight: 128,
            visual: AnyView(TutorialPlayGestureVisual())
        ),
        TutorialStep(
            title: "Play Matching Cards Together",
            message: "Have matching cards? Tap each card you want to include, then double tap one of them or drag the group to play them all.",
            callouts: [
                TutorialCallout(icon: "checkmark.circle.fill", title: "Tap to select", detail: "Tap each matching card you want to play before you send them to the pile."),
                TutorialCallout(icon: "rectangle.stack.fill", title: "One move", detail: "The selected matching cards land on the pile as a single play.")
            ],
            visualHeight: 130,
            visual: AnyView(TutorialMultiCardVisual())
        ),
        TutorialStep(
            title: "Picking Up The Center Pile",
            message: "If you do not have any eligible cards to play, you must pick up the center pile. You may also pick it up voluntarily if it helps your strategy. Sometimes picking up is smart if it lets you save a joker or wild card for later.",
            callouts: [
                TutorialCallout(icon: "tray.and.arrow.down.fill", title: "Cards move to your hand", detail: "The center pile cards become part of your hand."),
                TutorialCallout(icon: "lightbulb.fill", title: "Save power cards", detail: "Sometimes picking up is smart if it lets you save a joker or wild card for later.")
            ],
            visualHeight: 122,
            visual: AnyView(TutorialPickupVisual())
        ),
        TutorialStep(
            title: "Special Cards",
            message: "These cards change the normal pile rule. They are the ones worth learning first.",
            callouts: [],
            visualHeight: 210,
            visual: AnyView(TutorialSpecialCardsVisual())
        ),
        TutorialStep(
            title: "Four Of A Kind Burns",
            message: "When the top four cards on the pile are the same rank, the pile burns automatically and the current player goes again.",
            callouts: [
                TutorialCallout(icon: "square.stack.3d.up.fill", title: "They can stack up", detail: "The four matching cards can come from different turns."),
                TutorialCallout(icon: "flame.fill", title: "Burn means clear", detail: "The pile disappears instead of being picked up.")
            ],
            visualHeight: 124,
            visual: AnyView(TutorialFourKindVisual())
        ),
        TutorialStep(
            title: "Watch The Bright Player",
            message: "The active player stays bright. Everyone else dims a little so you can tell whose turn it is at a glance.",
            callouts: [
                TutorialCallout(icon: "person.crop.circle.fill", title: "You are at the bottom", detail: "Your cards are closest to you."),
                TutorialCallout(icon: "sparkles", title: "Easy mode helps", detail: "Easy mode keeps extra hints on screen while you learn.")
            ],
            visualHeight: 128,
            visual: AnyView(TutorialHighlightVisual())
        )
    ]
}

private struct TutorialCallout {
    let icon: String
    let title: String
    let detail: String
}

private struct TutorialPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.black.opacity(0.42))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.goldAccent.opacity(0.28), lineWidth: 1)
            )
    }
}

private struct TutorialZoneVisual: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 18) {
            VStack(spacing: 4) {
                CardView(card: Card(suit: .hearts, rank: .jack), faceUp: true, selected: animate, small: true)
                Text("Hand")
                    .font(.system(size: 10, weight: .black))
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color.goldAccent.opacity(0.75))

            VStack(spacing: 4) {
                HStack(spacing: -18) {
                    CardView(card: Card(suit: .clubs, rank: .six), faceUp: true, small: true)
                    CardView(card: Card(suit: .spades, rank: .ace), faceUp: false, small: true)
                }
                Text("Table")
                    .font(.system(size: 10, weight: .black))
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        .onAppear { animate = true }
    }
}

private struct TutorialSwapVisual: View {
    @State private var animate = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                CardView(card: Card(suit: .hearts, rank: .ace), faceUp: true, selected: animate, small: true)
                CardView(card: Card(suit: .clubs, rank: .four), faceUp: true, small: true)
                CardView(card: Card(suit: .spades, rank: .ten), faceUp: true, small: true)
            }
            .offset(y: animate ? 6 : 0)

            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goldAccent)
                .scaleEffect(animate ? 1.12 : 0.92)

            HStack(spacing: 10) {
                CardView(card: Card(suit: .diamonds, rank: .three), faceUp: true, small: true)
                CardView(card: Card(suit: .hearts, rank: .king), faceUp: true, selected: animate, small: true)
                CardView(card: Card(suit: .clubs, rank: .seven), faceUp: true, small: true)
            }
            .offset(y: animate ? -6 : 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

private struct TutorialBeatPileVisual: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            labeledCard("CENTER PILE") {
                CardView(card: Card(suit: .diamonds, rank: .nine), faceUp: true, small: true)
            }
            .offset(x: 54)

            CardView(card: Card(suit: .spades, rank: .queen), faceUp: true, highlight: true, small: true)
                .offset(x: animate ? 54 : -58, y: animate ? -8 : 8)
                .rotationEffect(.degrees(animate ? 5 : -8))
                .overlay(alignment: .bottom) {
                    Text("PLAY")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.white.opacity(0.74))
                        .offset(y: 20)
                        .opacity(animate ? 0 : 1)
                }

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.goldAccent)
                .offset(x: -8, y: -42)
                .opacity(animate ? 1 : 0.4)
            }
        .padding(.bottom, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

private struct TutorialPlayGestureVisual: View {
    @State private var dragAnimate = false
    @State private var tapAnimate = false

    var body: some View {
        HStack(spacing: 28) {
            VStack(spacing: 4) {
                Text("Drag")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.72))

                ZStack {
                    CardView(card: Card(suit: .clubs, rank: .eight), faceUp: true, small: true)
                        .opacity(0.68)
                        .offset(x: 34)

                    CardView(card: Card(suit: .hearts, rank: .king), faceUp: true, highlight: true, small: true)
                        .offset(x: dragAnimate ? 34 : -42, y: dragAnimate ? -6 : 14)
                        .rotationEffect(.degrees(dragAnimate ? 4 : -8))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.goldAccent)
                        .offset(y: -42)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 1, height: 96)

            VStack(spacing: 4) {
                Text("Double Tap")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.72))

                ZStack {
                    CardView(card: Card(suit: .diamonds, rank: .nine), faceUp: true, small: true)
                        .opacity(0.68)
                        .offset(x: 34)

                    CardView(card: Card(suit: .spades, rank: .queen), faceUp: true, highlight: true, small: true)
                        .offset(x: tapAnimate ? 34 : -34, y: tapAnimate ? -6 : 14)
                        .rotationEffect(.degrees(tapAnimate ? 4 : -6))

                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color.goldAccent)
                        .padding(8)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                        .offset(x: tapAnimate ? -28 : -44, y: tapAnimate ? 18 : 34)
                        .scaleEffect(tapAnimate ? 0.78 : 1.16)

                    Circle()
                        .stroke(Color.goldAccent.opacity(tapAnimate ? 0.0 : 0.75), lineWidth: 2)
                        .frame(width: tapAnimate ? 40 : 15, height: tapAnimate ? 40 : 15)
                        .offset(x: -34, y: 10)

                    Circle()
                        .stroke(Color.goldAccent.opacity(tapAnimate ? 0.0 : 0.55), lineWidth: 2)
                        .frame(width: tapAnimate ? 28 : 12, height: tapAnimate ? 28 : 12)
                        .offset(x: -18, y: 2)
                        .animation(.easeOut(duration: 0.22).repeatForever(autoreverses: false).delay(0.12), value: tapAnimate)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                dragAnimate = true
            }
            withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
                tapAnimate = true
            }
        }
    }
}

private struct TutorialMultiCardVisual: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: -14) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                CardView(card: card, faceUp: true, selected: animate, small: true)
                    .rotationEffect(.degrees(Double(index - 1) * 8))
                    .offset(x: animate ? 28 : 0, y: animate ? -8 : 0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(Double(index) * 0.08), value: animate)
            }
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.goldAccent)
                .padding(10)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .offset(x: 58, y: 34)
        }
        .onAppear { animate = true }
    }

    private var cards: [Card] {
        [
            Card(suit: .hearts, rank: .queen),
            Card(suit: .clubs, rank: .queen),
            Card(suit: .spades, rank: .queen)
        ]
    }
}

private struct TutorialPickupVisual: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: -12) {
            ForEach(0..<4, id: \.self) { index in
                CardView(
                    card: Card(suit: index.isMultiple(of: 2) ? .hearts : .clubs, rank: pickupRanks[index]),
                    faceUp: true,
                    small: true
                )
                .rotationEffect(.degrees(Double(index - 1) * 6))
                .offset(x: animate ? -20 : 0, y: CGFloat(abs(index - 1)) * 4)
            }
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(Color.goldAccent)
                .padding(11)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .offset(x: animate ? 4 : 42)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private var pickupRanks: [Rank] { [.five, .nine, .king, .two] }
}

private struct TutorialSpecialCardsVisual: View {
    private let cards: [(Card, String, String)] = [
        (Card(suit: .clubs, rank: .two), "2", "resets the pile"),
        (Card(suit: .spades, rank: .seven), "7", "next play is 7 or lower"),
        (Card(suit: .diamonds, rank: .eight), "8", "skips the next player"),
        (Card(suit: .clubs, rank: .nine), "9", "reverses direction"),
        (Card(suit: .hearts, rank: .ten), "10", "burns the pile"),
        (Card(suit: .spades, rank: .joker), "Joker", "choose who takes the pile")
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 8)], spacing: 8) {
            ForEach(cards, id: \.1) { item in
                HStack(spacing: 8) {
                    CardView(card: item.0, faceUp: true, small: true, style: .opponent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.1)
                            .font(.system(size: 13, weight: .black, design: .serif))
                        Text(item.2)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(TutorialPanelBackground())
            }
        }
        .frame(maxWidth: 520)
    }
}

private struct TutorialFourKindVisual: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: -18) {
            ForEach(Suit.allCases, id: \.self) { suit in
                CardView(card: Card(suit: suit, rank: .eight), faceUp: true, small: true)
                    .rotationEffect(.degrees(rotation(for: suit)))
                    .offset(y: offset(for: suit))
            }
        }
        .scaleEffect(animate ? 1.03 : 0.98)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "flame.fill")
                .font(.system(size: animate ? 34 : 27, weight: .black))
                .foregroundStyle(.orange)
                .shadow(color: .orange.opacity(0.45), radius: 8)
                .offset(x: 28, y: -10)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private func rotation(for suit: Suit) -> Double {
        switch suit {
        case .clubs: -12
        case .diamonds: -4
        case .spades: 4
        case .hearts: 12
        }
    }

    private func offset(for suit: Suit) -> CGFloat {
        switch suit {
        case .clubs, .hearts: 8
        case .diamonds, .spades: 0
        }
    }
}

private struct TutorialHighlightVisual: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 18) {
            TutorialPlayerToken(title: "AI", active: false, pulse: false)
            TutorialPlayerToken(title: "YOU", active: true, pulse: animate)
            TutorialPlayerToken(title: "AI", active: false, pulse: false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

private struct TutorialPlayerToken: View {
    let title: String
    let active: Bool
    let pulse: Bool

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(active ? Color.goldAccent.opacity(0.90) : Color.white.opacity(0.15))
                .frame(width: 46, height: 46)
                .overlay(
                    Text(title)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(active ? Color.black.opacity(0.80) : Color.white.opacity(0.46))
                )
                .scaleEffect(pulse ? 1.08 : 1)

            CardView(card: Card(suit: .spades, rank: active ? .king : .four), faceUp: true, small: true)
                .brightness(active ? 0.02 : -0.22)
                .saturation(active ? 1 : 0.75)
        }
        .opacity(active ? 1 : 0.72)
    }
}

private func labeledCard<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
    content()
        .overlay(alignment: .bottom) {
            Text(label)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white.opacity(0.74))
                .offset(y: 18)
        }
}

private struct TutorialControlButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.black.opacity(0.84) : .white.opacity(0.86))
            .background(
                Capsule()
                    .fill(prominent ? Color.goldAccent : Color.white.opacity(0.10))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(prominent ? 0.18 : 0.14), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private extension Color {
    static let goldAccent = Color(red: 0.96, green: 0.76, blue: 0.32)
}

#Preview("Tutorial") {
    TutorialSheet(onFinish: {}, onStartTutorialMode: {})
}
