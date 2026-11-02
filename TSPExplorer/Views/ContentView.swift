import SwiftUI

/// Presentation layout: a full-screen map with one card that controls everything.
/// One tab for the travelling salesman tour, one for Dijkstra's shortest path.
struct ContentView: View {
    @State private var model = ExplorerModel()
    @State private var showSettings = false

    var body: some View {
        TabView {
            ZStack(alignment: .bottom) {
                TourMap(model: model)
                    .ignoresSafeArea()

                ControlPanel(model: model)
                    .frame(maxWidth: 780)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .tabItem {
                Label(tr("Round Trip", "Rundreise"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }

            ShortestPathView(explorer: model)
                .tabItem {
                    Label(tr("Shortest Path", "Kürzester Weg"), systemImage: "arrow.triangle.turn.up.right.diamond")
                }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 52)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("Settings", "Einstellungen"))
            .padding(20)
            .popover(isPresented: $showSettings) {
                SettingsView(model: model)
                    .frame(width: 400, height: 680)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}
