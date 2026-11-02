import SwiftUI

/// The presentation card at the bottom of the map: which algorithm is showing,
/// its playback (or the results), and big Back / Next buttons to move between them.
struct ControlPanel: View {
    @Bindable var model: ExplorerModel
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if model.showingResults {
                ResultsView(model: model)
            } else if let step = model.currentStep {
                content(for: step)
            } else {
                emptyState
            }
            navigation
        }
        .padding(22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.showingResults ? tr("Analysis", "Auswertung") : model.algorithm.category.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(model.showingResults ? tr("Results", "Ergebnisse") : model.algorithm.title)
                    .font(.title.weight(.bold))
            }
            Spacer()
            if !model.showingResults {
                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title2)
                }
                .accessibilityLabel(tr("How It Works", "So funktioniert's"))
                .popover(isPresented: $showInfo) {
                    AlgorithmInfoView(algorithm: model.algorithm)
                        .frame(width: 400, height: 600)
                }
            }
        }
    }

    // MARK: Navigation

    /// Back and Next between the algorithms; after the last one, Next shows the results.
    private var navigation: some View {
        HStack(spacing: 14) {
            Button(action: model.previousChapter) {
                Label(tr("Back", "Zurück"), systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(model.previousUsableChapter == nil)
            .keyboardShortcut(.leftArrow, modifiers: .command)

            Button {
                model.showingResults ? model.goToChapter(0) : model.nextChapter()
            } label: {
                HStack {
                    Text(model.showingResults ? tr("Start Over", "Neu starten") : tr("Next", "Weiter"))
                    Image(systemName: model.showingResults ? "arrow.counterclockwise" : "chevron.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .font(.title3.weight(.semibold))
        .controlSize(.large)
    }

    // MARK: Playback

    private func content(for step: SolverStep) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if model.steps.contains(where: { $0.lowerBound != nil || $0.upperBound != nil }) {
                boundsBar(for: step)
            }

            Slider(
                value: Binding(
                    get: { Double(model.stepIndex) },
                    set: { model.scrub(to: Int($0.rounded())) }
                ),
                in: 0...Double(max(model.steps.count - 1, 1)),
                step: 1
            )

            HStack {
                HStack(spacing: 12) {
                    speedMenu
                    Text(tr("Step \(model.stepIndex + 1) of \(model.steps.count)", "Schritt \(model.stepIndex + 1) von \(model.steps.count)"))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                transport
                distance(for: step)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Button(action: model.rewind) {
                Image(systemName: "backward.end.fill")
            }
            .accessibilityLabel(tr("Back to start", "Zum Anfang"))

            Button(action: model.stepBackward) {
                Image(systemName: "backward.frame.fill")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .accessibilityLabel(tr("Previous step", "Vorheriger Schritt"))

            Button(action: model.togglePlay) {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(.tint))
                    .contentTransition(.symbolEffect(.replace))
            }
            .keyboardShortcut(.space, modifiers: [])
            .accessibilityLabel(model.isPlaying ? tr("Pause", "Pause") : tr("Play", "Abspielen"))

            // At the end of the animation, → moves on to the next algorithm, so a
            // presentation clicker can drive the whole talk.
            Button {
                model.isAtEnd ? model.nextChapter() : model.stepForward()
            } label: {
                Image(systemName: "forward.frame.fill")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .accessibilityLabel(tr("Next step", "Nächster Schritt"))

            Button(action: model.jumpToEnd) {
                Image(systemName: "forward.end.fill")
            }
            .accessibilityLabel(tr("Jump to result", "Zum Ergebnis"))
        }
        .font(.title3)
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var speedMenu: some View {
        Menu {
            Picker(tr("Speed", "Tempo"), selection: $model.speed) {
                ForEach(PlaybackSpeed.allCases) { speed in
                    Text(speed.title).tag(speed)
                }
            }
        } label: {
            Label(model.speed.title, systemImage: "gauge.with.dots.needle.33percent")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private func distance(for step: SolverStep) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(step.length.map(\.km) ?? "—")
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.snappy, value: step.length)
            Text(caption(for: step))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// For tours of non-exact algorithms, how far they are above Concorde's optimum.
    private func caption(for step: SolverStep) -> String {
        if step.isOptimal { return tr("Optimal", "Optimal") }
        if let kind = step.lengthKind { return kind.title }
        if step.isClosed, let length = step.length, let optimal = model.optimalLength {
            return OptimalGap.text(length, optimal)
        }
        return tr("Distance", "Strecke")
    }

    // MARK: Bounds

    /// The lower and upper bound of an exact solver closing in on the optimum. The
    /// scale is fixed for the whole run so the markers visibly move towards each other.
    private func boundsBar(for step: SolverStep) -> some View {
        let values = model.steps.flatMap { [$0.lowerBound, $0.upperBound].compactMap { $0 } }
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let pad = max((high - low) * 0.08, 1)
        let scale = (low - pad)...(high + pad)

        return VStack(spacing: 6) {
            GeometryReader { geometry in
                let x = { (value: Double) in
                    geometry.size.width * (value - scale.lowerBound) / (scale.upperBound - scale.lowerBound)
                }
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)
                    if let lower = step.lowerBound, let upper = step.upperBound {
                        Capsule()
                            .fill(Palette.candidate.opacity(0.35))
                            .frame(width: max(x(upper) - x(lower), 0), height: 8)
                            .offset(x: x(lower))
                    }
                    if let upper = step.upperBound {
                        marker(Palette.ghost).offset(x: x(upper) - 1.5)
                    }
                    if let lower = step.lowerBound {
                        marker(Palette.tour).offset(x: x(lower) - 1.5)
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)

            HStack {
                boundLabel(LengthKind.lowerBound.title, step.lowerBound, color: Palette.tour)
                Spacer()
                Text(gapText(for: step))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(step.isOptimal ? Palette.tour : Palette.candidate)
                Spacer()
                boundLabel(LengthKind.upperBound.title, step.upperBound, color: .secondary)
            }
        }
        .animation(.snappy, value: model.stepIndex)
    }

    private func marker(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 3, height: 20)
    }

    private func boundLabel(_ title: String, _ value: Double?, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            Text(value.map(\.km) ?? "—").foregroundStyle(color)
        }
        .font(.caption.monospacedDigit())
    }

    private func gapText(for step: SolverStep) -> String {
        guard let lower = step.lowerBound, let upper = step.upperBound else { return "" }
        if upper <= lower + 0.5 { return tr("Gap closed", "Lücke geschlossen") }
        return tr("Gap ", "Lücke ") + OptimalGap.percent(upper, lower) + tr("%", " %")
    }

    // MARK: Empty state

    private var emptyState: some View {
        let (symbol, title, detail): (String, String, String) = if model.missingPrecomputed {
            (
                "airplane.departure",
                tr("No Concorde result for these cities", "Kein Concorde-Ergebnis für diese Städte"),
                Concorde.isBundled
                    ? tr("Concorde was run ahead of time on the preset cities only. Use a preset region and count, with no cities tapped off or added.",
                         "Concorde wurde vorab nur für die vorgegebenen Städte berechnet. Wähle eine vorgegebene Region und Anzahl, ohne Städte abzuwählen oder hinzuzufügen.")
                    : tr("This build doesn't include Concorde results yet. Run Concorde/build_concorde.sh and Concorde/generate_results.py on a Mac, then rebuild.",
                         "Dieser Build enthält noch keine Concorde-Ergebnisse. Führe Concorde/build_concorde.sh und Concorde/generate_results.py auf einem Mac aus und baue die App neu.")
            )
        } else if model.exceedsLimit {
            (
                "exclamationmark.triangle",
                tr("Too many cities for an exact search", "Zu viele Städte für eine exakte Suche"),
                tr("\(model.algorithm.title) checks tours exhaustively, so it's limited to \(model.algorithm.maxCities ?? 0) cities.",
                   "\(model.algorithm.title) prüft Touren vollständig und ist deshalb auf \(model.algorithm.maxCities ?? 0) Städte begrenzt.")
            )
        } else {
            (
                "mappin.slash",
                tr("Not enough cities", "Zu wenige Städte"),
                tr("Choose at least 3 cities in Settings, or tap grey cities on the map to include them.",
                   "Wähle in den Einstellungen mindestens 3 Städte oder tippe graue Städte auf der Karte an.")
            )
        }
        return HStack(spacing: 16) {
            // No playback here, so → moves straight on to the next algorithm.
            Button(tr("Next", "Weiter"), action: model.nextChapter)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
