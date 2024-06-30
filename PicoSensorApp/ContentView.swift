//
//  ContentView.swift
//  PicoSensorApp
//
//  Created by Ivan Tabashki on 30.06.24.
//

import SwiftUI

struct ConnectedView: View {
    @Binding var peripheralName: String?
    @Binding var temperature: Float?
    @Binding var humidity: Float?
    var relays: [Binding<Bool>]

    var body: some View {
        VStack{
            Text("Connected to: ")
                .font(.title).fontWeight(.bold)
            Text("\(peripheralName ?? "(Unnamed)")")
                .font(.title).fontWeight(.light)
        }.padding()
        Divider()
        
        HStack(alignment: .center) {
            VStack{
                Text("Temperature:").font(.title2)
                if let temp = temperature {
                    Text("\(temp, specifier: "%.1f") °C").font(.title2.bold())
                } else {
                    ProgressView()
                }
            }

            Spacer().frame(width: 32)

            VStack {
                Text("Humidity:").font(.title2)
                if let humid = humidity {
                    Text("\(humid, specifier: "%.0f") %").font(.title2.bold())
                } else {
                    ProgressView()
                }
            }
        }.padding()
        Divider()
        
        ForEach(relays.indices, id: \.self) { index in
            Toggle("Relay \(index+1)", isOn: relays[index])
                .font(.title2).toggleStyle(.switch).frame(width: 200).padding()
        }
    }
}

struct ContentView: View {
    @StateObject var peripheralManager = PeripheralManager()

    var body: some View {
        let relays = peripheralManager.relays.enumerated().map({ (index, _) in
            Binding {
                return peripheralManager.relays[index]
            } set: { newValue in
                peripheralManager.setRelayState(index: index, value: newValue)
            }
        })
        
        VStack() {
            if (peripheralManager.isConnected) {
                ConnectedView(peripheralName: $peripheralManager.peripheralName,
                              temperature: $peripheralManager.temperature,
                              humidity: $peripheralManager.humidity,
                              relays: relays)
            } else {
                VStack {
                    Text("Searching for the sensor...").font(.title).bold()
                    ProgressView()
                }.padding()
            }
        }
    }
}

#Preview {
    struct CustomPreviewView : View {
        @State private var peripheralName: String? = "Preview Sensor Name"
        @State private var temperature: Float? = 23.45
        @State private var humidity: Float? = 43.21
        @State private var relay0 = true
        @State private var relay1 = false

        var body: some View {
            ConnectedView(peripheralName: $peripheralName, temperature: $temperature, humidity: $humidity, relays: [$relay0, $relay1])
        }
    }
    return CustomPreviewView()
}
