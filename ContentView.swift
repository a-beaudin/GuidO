//
//  ContentView.swift
//  GuidO
//
//  Created by Amelie Beaudin on 2024-06-14.
//


import GoogleGenerativeAI
import SwiftUI
import MapKit
import CoreLocation
import AVFoundation
import UIKit
import Combine

// Google Gemini API
// Input your own key in place of YOUR_API_KEY
let model = GenerativeModel(name: "gemini-1.5-flash", apiKey: "YOUR_API_KEY")


struct ContentView: View {
    @State private var cameraPosition: MapCameraPosition = .region(.userRegion)
    @State private var searchText = ""
    @State private var results = [MKMapItem]()
    @State private var lookAroundScene: MKLookAroundScene?
    @StateObject private var locationManager = LocationManager()
    @State private var mapSnapshot: UIImage?
    @State private var lookAroundSnapshot: UIImage?
    @State private var capturedImageSnapshot: UIImage?
    @State private var responseText: String?
    @State private var isLoading = false
    @State private var showMapSnapshot = true // Flag to control map snapshot visibility
    @State private var showLookAroundSnapshot = true // Flag to control look around snapshot visibility
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var showCameraView = false // For camera view presentation
    private let speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        GeometryReader { geometry in
            VStack {
                VStack {
                    Map(position: $cameraPosition) {
                        
                    }
                    .mapControls {
                        MapCompass()
                        MapUserLocationButton()
                    }
                    .onAppear {
                        locationManager.startUpdatingLocation()
                        fetchLookAroundPreview()
                    }
                    
                    if let scene = lookAroundScene {
                        LookAroundPreview(initialScene: scene)
                            .frame(height: 150) // Smaller height
                            .cornerRadius(12)
                            .padding()
                    } else {
                        Text("No preview available")
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                
                Divider()
                
                if showMapSnapshot {
                    if let mapSnapshot = mapSnapshot {
                        VStack {
                            Image(uiImage: mapSnapshot)
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.3) // Adjusted size
                            
                            Button(action: {
                                showMapSnapshot = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                    } else {
                        Text("Snapshot Loading...")
                            .padding()
                    }
                }
                
                if showLookAroundSnapshot {
                    if let lookAroundSnapshot = lookAroundSnapshot {
                        VStack {
                            Image(uiImage: lookAroundSnapshot)
                                .resizable()
                                .scaledToFit()
                                .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.3) // Adjusted size
                            
                            Button(action: {
                                showLookAroundSnapshot = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                    } else {
                        Text("Look Around Snapshot Loading...")
                            .padding()
                    }
                }
                
                if let capturedImage = capturedImageSnapshot {
                                VStack {
                                    Image(uiImage: capturedImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.3) // Adjusted size
                                    
                                    Button(action: {
                                        capturedImageSnapshot = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding()
                            }
                
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    if let responseText = responseText {
                        Text(responseText)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .onAppear {
                                speakResponse(responseText)
                            }
                    }
                }
                
                Spacer()
                
                HStack {
                    HStack(spacing: 10) {
                        // 'Intersection Type' button
                        Button(action: {
                            locationManager.startUpdatingLocation()
                            fetchLookAroundPreview()
                            hideAllSnapshots()
                            takeMapSnapshot()
                        }) {
                            VStack {
                                Text("Intersection Type")
                                    .font(.system(size: 10))
                                Image(systemName: "figure.walk.circle")
                                    .font(.system(size: 16))
                            }
                            .frame(width: (geometry.size.width / 4) - 20, height: 40)
                            .padding(5)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // 'Get Location' Button
                        Button(action: {
                            hideAllSnapshots() // Hide any open screenshots
                            locationManager.startUpdatingLocation()
                            fetchLookAroundPreview()
                            if let location = locationManager.userLocation {
                                let geocoder = CLGeocoder()
                                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                                    guard let placemark = placemarks?.first else {
                                        let response = "Location information not available."
                                        speakResponse(response)
                                        responseText = response
                                        return
                                    }
                                    var locationText = "You are at "
                                    if let street = placemark.thoroughfare {
                                        locationText += "\(street)"
                                    } else {
                                        locationText += "an unknown street"
                                    }
                                    if let direction = locationManager.heading {
                                        locationText += ". You're facing \(directionToString(direction))."
                                    }
                                    speakResponse(locationText)
                                    responseText = locationText
                                }
                            } else {
                                let response = "Location information not available."
                                speakResponse(response)
                                responseText = response
                            }
                        }) {
                            VStack {
                                Text("Get Location")
                                    .font(.system(size: 10))
                                Image(systemName: "signpost.right.and.left")
                                    .font(.system(size: 16))
                            }
                            .frame(width: (geometry.size.width / 4) - 20, height: 40)
                            .padding(5)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // 'Look Around' Button
                        Button(action: {
                            hideAllSnapshots()
                            locationManager.startUpdatingLocation()
                            fetchLookAroundPreview()
                            captureLookAroundSnapshot()
                        }) {
                            VStack {
                                Text("Look Around")
                                    .font(.system(size: 10))
                                Image(systemName: "poweroutlet.type.l")
                                    .font(.system(size: 16))
                            }
                            .frame(width: (geometry.size.width / 4) - 20, height: 40)
                            .padding(5)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // 'Capture Image' Button
                        Button(action: {
                            hideAllSnapshots()
                            showCameraView = true
                        }) {
                            VStack {
                                Text("Capture Image")
                                    .font(.system(size: 10))
                                Image(systemName: "camera")
                                    .font(.system(size: 16))
                            }
                            .frame(width: (geometry.size.width / 4) - 20, height: 40)
                            .padding(5)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(height: 40) // Fixed height for all buttons
                .padding()
            }
        }
        .padding()
        .sheet(isPresented: $showCameraView) {
            ImagePicker(sourceType: .camera, selectedImage: $inputImage)
                .onDisappear {
                    if let newImage = inputImage {
                        capturedImageSnapshot = newImage // Display the captured image
                        processCapturedImage(newImage) // Send the image to Gemini API for description
                    }
                }
        }
    }
    
    // Closes all open snapshots
    func hideAllSnapshots() {
        showMapSnapshot = false
        showLookAroundSnapshot = false
        capturedImageSnapshot = nil
    }
    
    // Takes a snapshot of the map in satellite view, displays it, and calls processSnapshot on the snapshot
    func takeMapSnapshot() {
        if let userLocation = locationManager.userLocation {
            let mapSnapshotOptions = MKMapSnapshotter.Options()
            mapSnapshotOptions.mapType = .satellite //satellite
            mapSnapshotOptions.region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 50, longitudinalMeters: 50)
            mapSnapshotOptions.scale = UIScreen.main.scale
            mapSnapshotOptions.size = CGSize(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.3) // Adjusted size
            let snapShotter = MKMapSnapshotter(options: mapSnapshotOptions)
            snapShotter.start { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    return
                }
                DispatchQueue.main.async {
                    hideAllSnapshots()
                    mapSnapshot = snapshot.image
                    showMapSnapshot = true
                    processSnapshot(snapshot.image)
                }
            }
        }
    }
    
    // Sends the snapshot to Google Gemini's API with the prompt, awaits the response, and then displays it
    func processSnapshot(_ image: UIImage) {
        isLoading = true
        Task {
            let prompt = "What kind of intersection is this? A cross intersection is when both roads cross and are aligned to make a cross. An offset intersection is when 2 roads don't exactly align at the intersection. Say whether it is a cross intersection, a T-intersection, or an offset intersection."
            do {
                let response = try await model.generateContent(prompt, image)
                if let text = response.text {
                    DispatchQueue.main.async {
                        responseText = text
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    responseText = "Error generating content: \(error)"
                    isLoading = false
                }
            }
        }
    }
    
    // Updates the LookAroundPreview to the user's current location
    func fetchLookAroundPreview() {
        Task {
            if let userLocation = locationManager.userLocation {
                let request = MKLookAroundSceneRequest(coordinate: userLocation.coordinate)
                lookAroundScene = try? await request.scene
            }
        }
    }
    
    // Takes a snapshot of the LookAroundPreview, displays it, and calls processLookAroundPreview on the snapshot
    func captureLookAroundSnapshot() {
        if let scene = lookAroundScene {
            let options = MKLookAroundSnapshotter.Options()
            let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
            
            snapshotter.getSnapshotWithCompletionHandler { snapshot, error in
                guard let snapshot = snapshot, error == nil else {
                    print("Error capturing Look Around snapshot: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                DispatchQueue.main.async {
                    hideAllSnapshots()
                    lookAroundSnapshot = snapshot.image
                    showLookAroundSnapshot = true
                    processLookAroundSnapshot(snapshot.image)
                }
            }
        }
    }
    
    // Sends the snapshot to Google Gemini's API with the prompt, awaits the response, and then displays it
    func processLookAroundSnapshot(_ image: UIImage) {
        isLoading = true
        Task {
            let prompt = "Tell me if there are street lights (yes or no), pedestrian lights (yes or no), or stop signs (yes or no)."
            do {
                let response = try await model.generateContent(prompt, image)
                if let text = response.text {
                    DispatchQueue.main.async {
                        responseText = text
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    responseText = "Error generating content: \(error)"
                    isLoading = false
                }
            }
        }
    }
    
    // Sends the picture captured through the app to Google Gemini's API with the prompt, awaits the response, and then displays it
    func processCapturedImage(_ image: UIImage) {
        isLoading = true
        Task {
            let prompt = "Describe the captured image in terms of whether it is safe to cross the street. Mention any traffic lights, pedestrian lights, and stop signs that are relevant. Don't mention anything that wouldn't help in making it safely across the street. Keep it concise."
            do {
                let response = try await model.generateContent(prompt, image)
                if let text = response.text {
                    DispatchQueue.main.async {
                        responseText = text
                        isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    responseText = "Error generating content: \(error)"
                    isLoading = false
                }
            }
        }
    }
    
    // text-to-speech function so that each output has audio feedback
    func speakResponse(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
    
    // Gives the user's direction in simple English terms
    func directionToString(_ direction: CLLocationDirection) -> String {
        let directions = ["North", "North-East", "East", "South-East", "South", "South-West", "West", "North-West"]
        let index = Int((direction + 22.5) / 45) & 7
        return directions[index]
    }
}

// class for obtaining and updating the user's location
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocation?
    var heading: CLLocationDirection?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            userLocation = location
            manager.stopUpdatingLocation() // Stop updating to save battery
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.magneticHeading
    }
}

// Region of Map displayed
extension MKCoordinateRegion {
    static var userRegion: MKCoordinateRegion {
        let coordinate = LocationManager().userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 45.504882, longitude: -73.573457)
        return .init(center: coordinate, latitudinalMeters: 50, longitudinalMeters: 50)
    }
}

// Used for managing the picture captured with the camera through the app
struct ImagePicker: UIViewControllerRepresentable {
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
