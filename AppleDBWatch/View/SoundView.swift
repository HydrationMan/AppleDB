//
//  SoundView.swift
//  AppleDBWatchApp
//
//  Created by Kane Parkinson on 07/04/2024.
//

import SwiftUI

struct SoundView: View {
    let hapticTypeAllValues: [(String, WKHapticType)] = [
        ("Notification",    .notification),
        ("DirectionUp",     .directionUp),
        ("DirectionDown",   .directionDown),
        ("Success",         .success),
        ("Failure",         .failure),
        ("Retry",           .retry),
        ("Start",           .start),
        ("Stop",            .stop),
        ("Click",           .click)
    ]

    var body: some View {
        ZStack {

            VStack {
                Text("Neat system sounds.")
                Text("Charging = No Haptics")
                Text("Mute = No Sound")
                List {
                    ForEach(hapticTypeAllValues, id: \.self.0) { hapticInfo in
                        HapticRowView(hapticName: hapticInfo.0, hapticType: hapticInfo.1)
                    }
                }
            }
        }
    }
}

struct HapticRowView: View {
    let AppleWatch = WKInterfaceDevice.current()
    let hapticName: String
    let hapticType: WKHapticType

    var body: some View {
        Button(action: { AppleWatch.play(self.hapticType)}) {
            Text("Play \(hapticName)")
        }
    }
}

