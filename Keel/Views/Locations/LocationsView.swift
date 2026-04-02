import SwiftUI
import MapKit

struct LocationsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddLocation = false
    @State private var selectedLocation: SavedLocation?
    @State private var showingDeleteConfirmation = false
    @State private var locationToDelete: SavedLocation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        Text("Locations")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        Button(action: {
                            HapticManager.shared.buttonTap()
                            showingAddLocation = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(Color.tertiaryBackground)
                                .clipShape(Circle())
                        }
                        .buttonStyle(HapticButtonStyle(hapticStyle: .button, scaleEffect: 0.92))
                    }
                    .padding(.horizontal)

                    // Current Location Section
                    if let currentLocation = appState.currentLocation {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Current Location")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.textSecondary)
                                .padding(.horizontal)

                            CurrentLocationCard(coordinate: currentLocation)
                                .padding(.horizontal)
                        }
                    }

                    // Saved Locations
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saved Locations")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.textSecondary)
                            .padding(.horizontal)

                        if appState.locations.isEmpty {
                            EmptyLocationsCard()
                                .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(appState.locations) { location in
                                    SavedLocationCard(location: location)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            HapticManager.shared.buttonTap()
                                            selectedLocation = location
                                        }
                                        .contextMenu {
                                            Button {
                                                HapticManager.shared.buttonTap()
                                                selectedLocation = location
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }

                                            Button(role: .destructive) {
                                                HapticManager.shared.warning()
                                                locationToDelete = location
                                                showingDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddLocation) {
                LocationEditorView(mode: .create)
            }
            .sheet(item: $selectedLocation) { location in
                LocationEditorView(mode: .edit(location))
            }
            .confirmationDialog(
                "Delete Location",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    HapticManager.shared.delete()
                    if let location = locationToDelete {
                        deleteLocation(location)
                    }
                }
                Button("Cancel", role: .cancel) {
                    HapticManager.shared.dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this location?")
            }
        }
    }

    private func deleteLocation(_ location: SavedLocation) {
        appState.deleteLocation(location)
    }
}

// MARK: - Current Location Card
struct CurrentLocationCard: View {
    let coordinate: CLLocationCoordinate2D
    @State private var address: String?

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: "location.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Your Location")
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                if let address = address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Text("Locating...")
                        .font(.subheadline)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            Circle()
                .fill(Color.statusOnline)
                .frame(width: 10, height: 10)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
        .task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                var parts: [String] = []
                if let street = placemark.thoroughfare { parts.append(street) }
                if let city = placemark.locality { parts.append(city) }
                address = parts.joined(separator: ", ")
            }
        }
    }
}

// MARK: - Saved Location Card
struct SavedLocationCard: View {
    let location: SavedLocation
    @EnvironmentObject var appState: AppState

    private var distance: String? {
        guard let current = appState.currentLocation else { return nil }
        return location.formattedDistance(from: current)
    }

    private var iconColor: Color {
        switch location.type {
        case .home: return Color.locationHome
        case .school: return Color.locationSchool
        case .library: return Color.locationLibrary
        case .office: return Color.locationOffice
        case .other: return Color.locationOther
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 48, height: 48)

                Image(systemName: location.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: 8) {
                    Text(location.type.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)

                    if let address = location.address {
                        Text("•")
                            .foregroundStyle(Color.textTertiary)
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let distance = distance {
                Text(distance)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Empty Locations Card
struct EmptyLocationsCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.textTertiary)

            Text("No saved locations")
                .font(.headline)
                .foregroundStyle(Color.textSecondary)

            Text("Add your home and school to get started")
                .font(.subheadline)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Location Editor
enum LocationEditorMode: Identifiable {
    case create
    case edit(SavedLocation)

    var id: String {
        switch self {
        case .create: return "create"
        case .edit(let location): return location.id.uuidString
        }
    }
}

struct LocationEditorView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let mode: LocationEditorMode

    @State private var name: String = ""
    @State private var type: LocationType = .school
    @State private var address: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var isSearching: Bool = false
    @StateObject private var searchCompleter = AddressSearchCompleter()

    init(mode: LocationEditorMode) {
        self.mode = mode

        switch mode {
        case .create:
            break
        case .edit(let location):
            _name = State(initialValue: location.name)
            _type = State(initialValue: location.type)
            _address = State(initialValue: location.address ?? "")
            _coordinate = State(initialValue: location.coordinate)
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Name & Type
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Details")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)

                        VStack(spacing: 0) {
                            TextField("Location Name", text: $name)
                                .padding()
                                .background(Color.tertiaryBackground)

                            Divider()
                                .background(Color.cardBorder)

                            Picker("Type", selection: $type) {
                                ForEach(LocationType.allCases) { locationType in
                                    Label(locationType.name, systemImage: locationType.defaultIcon)
                                        .tag(locationType)
                                }
                            }
                            .padding()
                            .background(Color.tertiaryBackground)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Address Search
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Address")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)

                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color.textTertiary)
                                TextField("Search address", text: $address)
                                    .textContentType(.fullStreetAddress)
                                    .autocorrectionDisabled()
                                    .onChange(of: address) { _, newValue in
                                        searchCompleter.search(query: newValue)
                                    }

                                if searchCompleter.isSearching {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else if !address.isEmpty {
                                    Button {
                                        address = ""
                                        searchCompleter.results = []
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.tertiaryBackground)

                            if !searchCompleter.results.isEmpty {
                                Divider()
                                    .background(Color.cardBorder)

                                ForEach(searchCompleter.results, id: \.self) { completion in
                                    Button {
                                        HapticManager.shared.selectionConfirm()
                                        selectCompletion(completion)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "mappin.and.ellipse.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(Color.accent)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(completion.title)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundStyle(Color.textPrimary)
                                                    .lineLimit(1)

                                                if !completion.subtitle.isEmpty {
                                                    Text(completion.subtitle)
                                                        .font(.caption)
                                                        .foregroundStyle(Color.textSecondary)
                                                        .lineLimit(2)
                                                }
                                            }
                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(Color.textTertiary)
                                        }
                                        .padding()
                                        .background(Color.tertiaryBackground)
                                    }

                                    if completion != searchCompleter.results.last {
                                        Divider()
                                            .background(Color.cardBorder)
                                    }
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Map
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pin Location")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)

                        ModernMapPicker(
                            coordinate: $coordinate,
                            cameraPosition: $cameraPosition
                        )
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        if appState.currentLocation != nil {
                            Button {
                                HapticManager.shared.mapFocus()
                                useCurrentLocation()
                            } label: {
                                HStack {
                                    Image(systemName: "location.fill")
                                    Text("Use Current Location")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.accent)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(HapticButtonStyle(hapticStyle: .button, scaleEffect: 0.98))
                        }
                    }
                }
                .padding()
            }
            .background(Color.background)
            .navigationTitle(isEditing ? "Edit Location" : "New Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.dismiss()
                        dismiss()
                    }
                    .foregroundStyle(Color.accent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        HapticManager.shared.success()
                        saveLocation()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(isValid ? Color.accent : Color.textTertiary)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if case .create = mode {
                    if let current = appState.currentLocation {
                        coordinate = current
                        cameraPosition = .region(MKCoordinateRegion(
                            center: current,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                        searchCompleter.setRegion(center: current)
                    }
                } else if let coord = coordinate {
                    searchCompleter.setRegion(center: coord)
                }
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isValid: Bool {
        !name.isEmpty && coordinate != nil
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        // Use MKLocalSearch to get the coordinate from the completion
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        Task {
            do {
                let response = try await search.start()
                if let mapItem = response.mapItems.first {
                    await MainActor.run {
                        coordinate = mapItem.placemark.coordinate
                        cameraPosition = .region(MKCoordinateRegion(
                            center: mapItem.placemark.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))

                        if name.isEmpty {
                            name = completion.title
                        }

                        address = [completion.title, completion.subtitle]
                            .filter { !$0.isEmpty }
                            .joined(separator: ", ")

                        searchCompleter.results = []
                    }
                }
            } catch {
                print("Failed to get location from completion: \(error)")
            }
        }
    }

    private func useCurrentLocation() {
        if let current = appState.currentLocation {
            coordinate = current
            cameraPosition = .region(MKCoordinateRegion(
                center: current,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))

            Task {
                let geocoder = CLGeocoder()
                let location = CLLocation(latitude: current.latitude, longitude: current.longitude)
                if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                    var parts: [String] = []
                    if let number = placemark.subThoroughfare { parts.append(number) }
                    if let street = placemark.thoroughfare { parts.append(street) }
                    if let city = placemark.locality { parts.append(city) }
                    address = parts.joined(separator: " ")
                }
            }
        }
    }

    private func saveLocation() {
        guard let coord = coordinate else { return }

        let location = SavedLocation(
            id: existingLocationId ?? UUID(),
            name: name,
            coordinate: coord,
            type: type,
            address: address.isEmpty ? nil : address
        )

        // Save using AppState (handles local storage)
        appState.saveLocation(location)

        dismiss()
    }

    private var existingLocationId: UUID? {
        if case .edit(let location) = mode {
            return location.id
        }
        return nil
    }
}

// MARK: - Address Search Completer
class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching: Bool = false

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        super.init()
        completer.delegate = self
    }

    func search(query: String) {
        guard query.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        completer.queryFragment = query
    }

    func setRegion(center: CLLocationCoordinate2D) {
        completer.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 100000,
            longitudinalMeters: 100000
        )
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = Array(completer.results.prefix(6))
            self.isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.results = []
            self.isSearching = false
        }
    }
}

// MARK: - Modern Map Picker (iOS 17+)
struct ModernMapPicker: View {
    @Binding var coordinate: CLLocationCoordinate2D?
    @Binding var cameraPosition: MapCameraPosition

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                if let coord = coordinate {
                    Marker("", coordinate: coord)
                        .tint(.red)
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                coordinate = context.camera.centerCoordinate
            }

            // Center crosshair
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.light)
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    LocationsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
