import SwiftUI
import Starscream

struct ContentView: View {
    @ObservedObject private var websocketVM = WebSocketManager()
    @State private var showEventsList: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Button(websocketVM.isConnected ? "Connected" : "Connect") {
                if websocketVM.isConnected {
                    websocketVM.disconnect()
                } else {
                    websocketVM.connect()
                }
            }
            .padding()
            .background(websocketVM.isConnected ? Color.green : Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            Button("Subscribe to Events") {
                websocketVM.subscribeToEvents()
                showEventsList = true
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .fullScreenCover(isPresented: $showEventsList) {
                NavigationView {
                    EventsListView(websocketVM: websocketVM)
                }
                .edgesIgnoringSafeArea(.bottom) // Ignore safe area at the bottom
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
