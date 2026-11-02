import SwiftUI

/// "How it works" popover: explanation, steps, facts and a map legend.
struct AlgorithmInfoView: View {
    let algorithm: Algorithm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(algorithm.category.title, systemImage: algorithm.symbol)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(algorithm.title)
                        .font(.title2.weight(.bold))
                    Text(algorithm.summary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("How It Works", "So funktioniert's"))
                        .font(.headline)
                    ForEach(Array(algorithm.howItWorks.enumerated()), id: \.offset) { index, text in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(.tint))
                            Text(text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                HStack(spacing: 12) {
                    FactTile(title: tr("Running Time", "Laufzeit"), value: algorithm.complexity)
                    FactTile(title: tr("Tour Quality", "Tourqualität"), value: algorithm.quality)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("On the Map", "Auf der Karte"))
                        .font(.headline)
                    LegendRow(color: Palette.tour, label: tr("Tour or route so far", "Tour bzw. bisherige Route"))
                    LegendRow(color: Palette.candidate, label: algorithm == .concorde
                        ? tr("Connection used only half (LP)", "Nur halb genutzte Verbindung (LP)")
                        : tr("Being considered or just added", "Wird geprüft oder neu hinzugefügt"))
                    LegendRow(color: Palette.removed, dashed: true, label: tr("Rejected or removed", "Abgelehnt oder entfernt"))
                    LegendRow(color: Palette.ghost, dashed: true, label: tr("Best tour found so far", "Bisher beste Tour"))
                    if algorithm == .antColony || algorithm == .doubleTree {
                        LegendRow(color: Palette.trail.opacity(0.4), label: algorithm == .antColony
                            ? tr("Pheromone (thicker = more)", "Pheromon (dicker = mehr)")
                            : tr("Spanning tree", "Spannbaum"))
                    }
                    Text(tr("Tap a city on the map to leave it out of the tour.", "Tippe eine Stadt auf der Karte an, um sie aus der Tour zu nehmen."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(24)
        }
    }
}

struct FactTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct LegendRow: View {
    let color: Color
    var dashed = false
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Path { path in
                path.move(to: CGPoint(x: 2, y: 2))
                path.addLine(to: CGPoint(x: 28, y: 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: dashed ? [5, 5] : []))
            .frame(width: 30, height: 4)
            Text(label)
                .font(.subheadline)
        }
    }
}
