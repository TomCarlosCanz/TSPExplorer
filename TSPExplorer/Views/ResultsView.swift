import SwiftUI

/// The last chapter: every algorithm's final tour, ranked against the optimum.
/// Tap a row to see that tour on the map.
struct ResultsView: View {
    @Bindable var model: ExplorerModel

    var body: some View {
        let results = model.results
        if results.isEmpty {
            Text(tr("Choose at least 3 cities in Settings to compare the algorithms.", "Wähle in den Einstellungen mindestens 3 Städte, um die Algorithmen zu vergleichen."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ranking(results)
        }
    }

    // MARK: Ranking

    private func ranking(_ results: [ComparisonResult]) -> some View {
        let shortest = results.map(\.length).min() ?? 0
        let longest = results.map(\.length).max() ?? 1
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(results.enumerated()), id: \.element.id) { rank, result in
                let isShown = result.algorithm == (model.highlightedResult ?? referenceAlgorithm(results))
                Button {
                    model.highlightedResult = result.algorithm
                } label: {
                    HStack(spacing: 10) {
                        Text("\(rank + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Image(systemName: result.algorithm.symbol)
                            .foregroundStyle(.tint)
                            .frame(width: 22)
                        Text(result.algorithm.title)
                            .font(.subheadline.weight(isShown ? .semibold : .regular))
                            .frame(width: 150, alignment: .leading)
                        bar(for: result, shortest: shortest, longest: longest)
                        Text(result.length.km)
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 84, alignment: .trailing)
                        Text(result.gapText)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(result.isBest ? Palette.tour : .secondary)
                            .frame(width: 74, alignment: .trailing)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isShown ? Color.accentColor.opacity(0.12) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text(tr("Tap an algorithm to see its tour on the map. Dashed: the shortest tour.", "Tippe einen Algorithmus an, um seine Tour auf der Karte zu sehen. Gestrichelt: die kürzeste Tour."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.leading, 8)
        }
    }

    /// Bars start at the shortest tour, so differences of a few percent stay visible.
    private func bar(for result: ComparisonResult, shortest: Double, longest: Double) -> some View {
        let fraction = longest > shortest ? (result.length - shortest) / (longest - shortest) : 0
        return GeometryReader { geometry in
            Capsule()
                .fill(result.isBest ? Palette.tour : Palette.tour.opacity(0.35))
                .frame(width: geometry.size.width * (0.08 + 0.92 * fraction), height: 10)
                .frame(maxHeight: .infinity)
        }
        .frame(height: 18)
    }

    private func referenceAlgorithm(_ results: [ComparisonResult]) -> Algorithm? {
        results.first { $0.algorithm == .concorde }?.algorithm ?? results.first?.algorithm
    }
}
