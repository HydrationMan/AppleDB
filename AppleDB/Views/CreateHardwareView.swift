//
//  CreateHardwareView.swift
//  AppleDB
//
//  Created by Kane Parkinson on 07/08/2024.
//

import SwiftUI
import Combine
import Foundation

struct CreateHardwareView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = DeviceViewModel()

    @State private var showFilteredTypes: Bool = false
    @State private var selectedType: String?
    @State private var selectedDevice: DeviceListEntry?
    @State private var selectedBoard: String?

    @State private var firmwareMode: String = "Release" // Default to "Release"
    @State private var firmwareEntries: [FirmwareEntry] = []
    @State private var selectedFirmware: FirmwareEntry?
    @State private var isLoadingFirmware = false

    let hardwareProvider = HardwareProvider.shared
    @ObservedObject var vm: EditHardwareViewModel

    var body: some View {
        NavigationView {
            Form {
                // Device Type Selection Section
                Section(header: Text("Device Type").font(.headline)) {
                    Toggle("Show more devices", isOn: $showFilteredTypes)
                        .padding(.vertical, 5)

                    Picker("Select Device Type", selection: $selectedType) {
                        Text("Select a type").tag(nil as String?)
                        ForEach(filteredDeviceTypes, id: \.self) { type in
                            Text(type).tag(type as String?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedType) { newType in
                        withAnimation(.easeInOut) {
                            if newType != nil {
                                selectedDevice = nil
                            }
                        }
                    }
                }

                // Device Selection Section
                if let selectedType = selectedType {
                    Section(header: Text("Select a \(selectedType)").font(.headline)) {
                        Picker("Select Device", selection: $selectedDevice) {
                            Text("Select a \(selectedType)").tag(nil as DeviceListEntry?)
                            
                            ForEach(viewModel.devices
                                .filter { $0.type == selectedType && !$0.name.contains("Unreleased") }
                                .sorted { lhs, rhs in
                                    guard let lhsDate = parseReleaseDate(lhs.released),
                                          let rhsDate = parseReleaseDate(rhs.released) else {
                                        return false
                                    }
                                    return lhsDate < rhsDate
                                }, id: \.self) { device in
                                    Text(device.name).tag(device as DeviceListEntry?)
                                }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: selectedDevice) { newDevice in
                            if let device = newDevice {
                                fetchFirmwareData(for: device)
                            }
                        }
                    }
                }

                // Device Details Section
                if let details = selectedDevice {
                    Section(header: Text("Device Details").font(.headline)) {
                        Text("Device Name: \(details.name)")
                        Text("SoC: \(details.soc)")
                        Text("Identifier: \(details.identifier?.joined(separator: ", ") ?? "Unknown")")
                        Text("Architecture: \(details.arch ?? "Unknown")")
                        Text("Type: \(details.type)")
                        Text("Released: \(details.released.joined(separator: ", "))")

                        if let boardOptions = details.board, boardOptions.count > 1 {
                            Picker("Select Board", selection: $selectedBoard) {
                                ForEach(boardOptions, id: \.self) { board in
                                    Text(board).tag(board)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        } else {
                            Text("Board: \(details.board?.first ?? "Unknown")")
                                .onAppear {
                                    selectedBoard = details.board?.first
                                }
                        }
                    }
                }

                // Firmware Selection Section
                if isLoadingFirmware {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading Firmware...")
                            Spacer()
                        }
                    }
                } else if !firmwareEntries.isEmpty {
                    // Filter firmware entries based on selected mode
                    let filteredFirmwares: [FirmwareEntry] = {
                        if firmwareMode == "Release" {
                            return firmwareEntries.filter { $0.beta == false && ($0.internalVersion == false || $0.internalVersion == nil) }
                        } else {
                            return firmwareEntries.filter { $0.beta == true && ($0.internalVersion == false || $0.internalVersion == nil) }
                        }
                    }()

                    // Sort firmware entries
                    let sortedFirmwares = filteredFirmwares.sorted(by: { lhs, rhs in
                        let versionComparison = lhs.version.compare(rhs.version, options: .numeric)
                        if versionComparison != .orderedSame {
                            return versionComparison == .orderedAscending
                        }
                        return (lhs.build ?? "").compare(rhs.build ?? "", options: .numeric) == .orderedAscending
                    })

                    
                    // Firmware Mode Picker
                    Section {
                        Picker("Firmware Mode", selection: $firmwareMode) {
                            Text("Release").tag("Release")
                            Text("Beta").tag("Beta")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.vertical, 5)
                    }
                    
                    // Firmware Picker
                    Section(header: Text("Select Firmware").font(.headline)) {
                        Picker("Firmware Version", selection: $selectedFirmware) {
                            ForEach(sortedFirmwares, id: \.self) { firmware in
                                Text("\(firmware.version) - \(firmware.build ?? "Unknown")")
                                    .tag(firmware as FirmwareEntry?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }

                // Save Button
                Section {
                    Button(action: {
                        saveDeviceToCoreData(selectedDevice!)
                    }) {
                        Text("Save Device")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(canSave ? Color.accentColor : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Add New Hardware")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.fetchDeviceList()
            }
        }
    }

    // MARK: - Helper Methods

    private var filteredDeviceTypes: [String] {
        let allTypes = Array(Set(viewModel.devices.map { $0.type })).sorted()
        let predefinedTypes = ["iPhone", "iPad", "iPad Pro", "iPad Air", "iPad mini", "Apple Watch", "Apple TV", "AirPods", "Headset", "MacBook", "MacBook Air", "MacBook Pro", "Mac Pro", "Mac mini", "Mac Studio", "HomePod"]
        return showFilteredTypes ? allTypes : allTypes.filter { predefinedTypes.contains($0) }
    }

    private var canSave: Bool {
        // Check if all required fields are selected
        guard let _ = selectedType,
              let _ = selectedDevice else {
            return false
        }

        // If multiple boards are available, ensure a board is selected
        if let details = selectedDevice, let boardOptions = details.board, boardOptions.count > 1 {
            return selectedBoard != nil
        }

        return true
    }

    private func saveDeviceToCoreData(_ device: DeviceListEntry) {
        vm.hardware.identifier = device.identifier?.first ?? "Unknown"
        vm.hardware.device = device.name
        vm.hardware.type = device.type
        vm.hardware.chip = device.soc
        vm.hardware.version = selectedFirmware?.version ?? "Unknown"
        vm.hardware.build = selectedFirmware?.build ?? "Unknown"
        vm.hardware.osStr = selectedFirmware?.osStr ?? "Unknown"
        vm.hardware.board = selectedBoard ?? "Unknown"

        do {
            try vm.save()
            firmwareEntries = [] // Free up memory
            viewModel.devices = [] // Free up memory
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Failed to save hardware to CoreData: \(error)")
        }
    }
    private func fetchFirmwareData(for device: DeviceListEntry) {
        isLoadingFirmware = true

        let normalizedIdentifier = normalizeIdentifier(from: device)
        guard let url = URL(string: "https://api.appledb.dev/device/\(normalizedIdentifier).json") else {
            print("Error: Unable to create URL for device identifier \(normalizedIdentifier).")
            isLoadingFirmware = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error fetching firmware data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingFirmware = false
                }
                return
            }

            guard let data = data else {
                print("Error: No data received from URL \(url.absoluteString).")
                DispatchQueue.main.async {
                    self.isLoadingFirmware = false
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let fetchedDevice = try decoder.decode(DeviceListEntry.self, from: data)
                DispatchQueue.main.async {
                    // Free the fetchedDevice if we only need its firmware
                    self.fetchFirmwareEntries(for: normalizedIdentifier)
                }
            } catch {
                print("Error decoding JSON: \(error)")
                DispatchQueue.main.async {
                    self.isLoadingFirmware = false
                }
            }
        }.resume()
    }

    
    private func sortBuildNumbers(_ build1: String?, _ build2: String?) -> Bool {
        guard let build1 = build1, let build2 = build2 else {
            return build1 != nil
        }
        return build1.compare(build2, options: .numeric) == .orderedDescending
    }
    
    private func isValidFirmware(_ firmware: FirmwareEntry) -> Bool {
        // Include only entries where `internalVersion` is false or does not exist
        firmware.internalVersion == false || firmware.internalVersion == nil
    }
    
    private func normalizeIdentifier(from device: DeviceListEntry) -> String {
        guard let baseIdentifier = device.identifier?.first else {
            print("Error: Device has no base identifier.")
            return "UnknownIdentifier"
        }

        // Log the base identifier and key
        print("Base Identifier: \(baseIdentifier)")
        print("Device Key: \(device.key)")

        // If the `key` does not match the `baseIdentifier`, a suffix is needed
        if device.key != baseIdentifier {
            // Extract the year from the `released` key
            if let releaseDate = device.released.first,
               let year = releaseDate.split(separator: "-").first {
                print("Appending year suffix \(year) to identifier \(baseIdentifier).")
                return "\(baseIdentifier)-\(year)"
            }
        }

        // No suffix needed, return the base identifier
        print("No year suffix needed for \(baseIdentifier).")
        return baseIdentifier
    }
    
    private func fetchFirmwareEntries(for identifier: String) {
        guard let url = URL(string: "https://api.appledb.dev/ios/main.json") else {
            print("Error: Unable to create firmware URL.")
            isLoadingFirmware = false
            return
        }

        print("Fetching firmware entries for identifier: \(identifier)")
        print("Request URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error fetching firmware entries: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingFirmware = false
                }
                return
            }

            guard let data = data else {
                print("Error: No data received from URL \(url.absoluteString).")
                DispatchQueue.main.async {
                    self.isLoadingFirmware = false
                }
                return
            }

            do {
                let decodedData = try JSONDecoder().decode([FirmwareEntry].self, from: data)
                print("Fetched \(decodedData.count) firmware entries.")

                DispatchQueue.main.async {
                    self.firmwareEntries = decodedData.filter { $0.deviceMap.contains(identifier) }
                        .sorted { sortBuildNumbers($0.build, $1.build) }
                    
                    print("Filtered firmware entries: \(self.firmwareEntries.map { "\($0.version) - \($0.build ?? "Unknown")" })")

                    self.selectedFirmware = self.firmwareEntries.first
                    print("Selected firmware: \(self.selectedFirmware?.version ?? "None")")
                    self.isLoadingFirmware = false
                }
            } catch {
                print("Error decoding firmware JSON: \(error)")
                DispatchQueue.main.async {
                    self.isLoadingFirmware = false
                }
            }
        }.resume()
    }
    
    private func sortBetaFirmwares(_ lhs: FirmwareEntry, _ rhs: FirmwareEntry) -> Bool {
        // Sort Beta builds numerically by version and build
        let versionComparison = lhs.version.compare(rhs.version, options: .numeric)
        if versionComparison != .orderedSame {
            return versionComparison == .orderedAscending
        }
        return (lhs.build ?? "").compare(rhs.build ?? "", options: .numeric) == .orderedAscending
    }
    
    private func sortReleaseFirmwares(_ lhs: FirmwareEntry, _ rhs: FirmwareEntry) -> Bool {
        // Sort Release builds numerically by version and build
        let versionComparison = lhs.version.compare(rhs.version, options: .numeric)
        if versionComparison != .orderedSame {
            return versionComparison == .orderedAscending
        }
        return (lhs.build ?? "").compare(rhs.build ?? "", options: .numeric) == .orderedAscending
    }
    
    private func parseReleaseDate(_ releaseDates: [String]) -> Date? {
        // Assume the `released` property is a list of release dates in "yyyy-MM-dd" format
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Try to parse the earliest release date
        for dateString in releaseDates {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}
