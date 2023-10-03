import SwiftUI

struct EventsListView: View {
    @ObservedObject var websocketVM: WebSocketManager

    var body: some View {
        List(websocketVM.eventsReceived, id: \.self) { event in
            Text(event)
        }
        .navigationBarTitle("Received Events", displayMode: .inline)
        .listStyle(PlainListStyle())
        .padding(.bottom, bottomSafeAreaInsets()) // Use the new extension method here
    }
}
