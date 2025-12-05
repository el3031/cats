//
//  MoodleApp.swift
//  Moodle
//
//  Created by Elaine Lee on 11/24/25.
//

import SwiftUI

@main
struct MoodleApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showLoading = true

    init() {
        // Debug: List available fonts on app launch
        #if DEBUG
        FontHelper.listAvailableFonts()
        #endif
        
        // Set up default cat profile images on first launch
        setupDefaultCatImages()
    }
    
    private func setupDefaultCatImages() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ ERROR: Could not access documents directory")
            return
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        
        // Create images directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
                print("✅ Created cat_images directory at: \(imagesDirectory.path)")
            } catch {
                print("❌ ERROR: Could not create cat_images directory: \(error.localizedDescription)")
                return
            }
        }
        
        // Copy default images from bundle if they don't exist
        let defaultImages = [
            ("noodle_profile", "noodle_profile.jpg"),
            ("boba_profile", "boba_profile.jpg")
        ]
        
        for (bundleName, fileName) in defaultImages {
            let destinationURL = imagesDirectory.appendingPathComponent(fileName)
            
            // Only copy if file doesn't already exist
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                // Try multiple ways to find the image in bundle
                var bundleImageURL: URL? = nil
                
                // Try with full filename
                bundleImageURL = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".jpg", with: ""), withExtension: "jpg")
                
                // Try with just the name without _profile
                if bundleImageURL == nil {
                    bundleImageURL = Bundle.main.url(forResource: bundleName, withExtension: "jpg")
                }
                
                // Try without extension
                if bundleImageURL == nil {
                    bundleImageURL = Bundle.main.url(forResource: bundleName, withExtension: nil)
                }
                
                if let bundleImageURL = bundleImageURL {
                    do {
                        try FileManager.default.copyItem(at: bundleImageURL, to: destinationURL)
                        print("✅ Copied default image: \(fileName) from bundle")
                    } catch {
                        print("⚠️  Could not copy \(fileName): \(error.localizedDescription)")
                    }
                } else {
                    print("ℹ️  Default image \(fileName) not found in bundle")
                    print("   Looking for: \(bundleName).jpg or \(fileName)")
                    print("   Documents directory: \(documentsDirectory.path)")
                    print("   Images directory: \(imagesDirectory.path)")
                }
            } else {
                print("ℹ️  Image \(fileName) already exists at: \(destinationURL.path)")
            }
        }
        
        // List all files in the images directory for debugging
        if let files = try? FileManager.default.contentsOfDirectory(atPath: imagesDirectory.path) {
            print("📁 Files in cat_images directory: \(files)")
        }
        
        // If profile images don't exist, try to create them from existing cat images
        createProfileImagesFromExistingImages()
    }
    
    private func createProfileImagesFromExistingImages() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let imagesDirectory = documentsDirectory.appendingPathComponent("cat_images")
        let jsonFileURL = documentsDirectory.appendingPathComponent("pain_analysis_entries.json")
        
        // Check if profile images exist
        let noodleProfilePath = imagesDirectory.appendingPathComponent("noodle_profile.jpg")
        let bobaProfilePath = imagesDirectory.appendingPathComponent("boba_profile.jpg")
        
        var needsNoodle = !FileManager.default.fileExists(atPath: noodleProfilePath.path)
        var needsBoba = !FileManager.default.fileExists(atPath: bobaProfilePath.path)
        
        if !needsNoodle && !needsBoba {
            return // Both profile images exist
        }
        
        // Try to find images from JSON entries
        guard let data = try? Data(contentsOf: jsonFileURL),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        
        // Find most recent image for each cat
        var noodleImagePath: String? = nil
        var bobaImagePath: String? = nil
        var noodleDate: Date? = nil
        var bobaDate: Date? = nil
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for entry in entries {
            guard let catName = entry["catName"] as? String,
                  let dateTimeString = entry["dateTime"] as? String,
                  let date = dateFormatter.date(from: dateTimeString),
                  let imagePath = entry["imagePath"] as? String else {
                continue
            }
            
            let fullImagePath = documentsDirectory.appendingPathComponent(imagePath).path
            
            if catName.lowercased() == "noodle" && needsNoodle {
                if FileManager.default.fileExists(atPath: fullImagePath) {
                    if noodleDate == nil || date > noodleDate! {
                        noodleImagePath = fullImagePath
                        noodleDate = date
                    }
                }
            } else if catName.lowercased() == "boba" && needsBoba {
                if FileManager.default.fileExists(atPath: fullImagePath) {
                    if bobaDate == nil || date > bobaDate! {
                        bobaImagePath = fullImagePath
                        bobaDate = date
                    }
                }
            }
        }
        
        // Copy the most recent images as profile images
        if let noodlePath = noodleImagePath, needsNoodle {
            do {
                try FileManager.default.copyItem(at: URL(fileURLWithPath: noodlePath), to: noodleProfilePath)
                print("✅ Created noodle_profile.jpg from existing image")
            } catch {
                print("⚠️  Could not create noodle_profile.jpg: \(error.localizedDescription)")
            }
        }
        
        if let bobaPath = bobaImagePath, needsBoba {
            do {
                try FileManager.default.copyItem(at: URL(fileURLWithPath: bobaPath), to: bobaProfilePath)
                print("✅ Created boba_profile.jpg from existing image")
            } catch {
                print("⚠️  Could not create boba_profile.jpg: \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showLoading {
                    LoadingView()
                        .transition(.opacity)
                        .zIndex(1)
                } else {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .transition(.opacity)
                        .zIndex(0)
                }
            }
            .onAppear {
                // Show loading screen for 2 seconds, then transition to ContentView
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showLoading = false
                    }
                }
            }
        }
    }
}
