//
//  CoreMLInference.swift
//  Moodle
//
//  Core ML inference for cat facial landmark detection
//

import Foundation
import CoreML
import UIKit
import Accelerate

// MARK: - Core ML Landmark Predictor
class CoreMLLandmarkPredictor {
    private var model: MLModel?
    
    init() {
        loadModel()
    }
    
    private func loadModel() {
        // Load the Core ML model from the app bundle
        // Try .mlpackage first (ML Program format), then .mlmodelc (compiled), then .mlmodel (NeuralNetwork)
        guard let modelURL = Bundle.main.url(forResource: "CatLandmarkModel", withExtension: "mlpackage") ??
                             Bundle.main.url(forResource: "CatLandmarkModel", withExtension: "mlmodelc") ??
                             Bundle.main.url(forResource: "CatLandmarkModel", withExtension: "mlmodel") else {
            print("⚠️  Core ML model not found in bundle")
            print("   Please add CatLandmarkModel.mlpackage (or .mlmodel) to your Xcode project")
            return
        }
        
        do {
            let modelConfig = MLModelConfiguration()
            // Use CPU-only for consistency with PyTorch CPU inference
            // This helps ensure numerical consistency and avoids potential GPU/Neural Engine quantization differences
            modelConfig.computeUnits = .cpuOnly
            model = try MLModel(contentsOf: modelURL, configuration: modelConfig)
            print("✅ Core ML model loaded successfully")
            print("   Model URL: \(modelURL)")
            print("   Compute units: CPU only (for consistency with PyTorch)")
        } catch {
            print("❌ Error loading Core ML model: \(error)")
        }
    }
    
    /// Predict landmarks from a cat image
    /// - Parameter image: UIImage of the cat
    /// - Returns: Array of 48 landmarks as (x, y) tuples in pixel coordinates, or nil if prediction fails
    func predictLandmarks(from image: UIImage) -> [(x: Double, y: Double)]? {
        guard let model = model else {
            print("❌ Model not loaded")
            return nil
        }
        
        // CRITICAL: Fix image orientation first
        // PIL automatically handles EXIF orientation when loading images, so we need to match that
        // This ensures the image we process matches what the model was trained on
        let orientedImage = image.fixedOrientation()
        let originalSize = orientedImage.size
        
        // Preprocess image: resize to 224x224 and normalize
        guard let pixelBuffer = preprocessImage(orientedImage) else {
            print("❌ Failed to preprocess image")
            return nil
        }
        
        do {
            // Create input - need to convert pixel buffer to MLMultiArray with normalization
            // Model expects: (pixel / 255.0 - mean) / std
            // mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225]
            guard let normalizedArray = normalizePixelBufferToArray(pixelBuffer) else {
                print("❌ Failed to normalize image")
                return nil
            }
            
            let input = try MLFeatureValue(multiArray: normalizedArray)
            let modelInput = try MLDictionaryFeatureProvider(dictionary: ["image": input])
            
            // Predict
            let prediction = try model.prediction(from: modelInput)
            
            // Get output
            guard let landmarksOutput = prediction.featureValue(for: "landmarks")?.multiArrayValue else {
                print("❌ Failed to get landmarks output")
                return nil
            }
            
            // Convert to array of coordinates using the oriented image size
            let landmarks = extractLandmarks(from: landmarksOutput, originalImageSize: originalSize)
            
            return landmarks
            
        } catch {
            print("❌ Error during prediction: \(error)")
            return nil
        }
    }
    
    /// Preprocess image: resize to 224x224 and convert to CVPixelBuffer
    /// Note: PyTorch's Resize((224, 224)) stretches the image to exactly 224x224 (doesn't maintain aspect ratio)
    /// Note: Image orientation should already be fixed before calling this function
    private func preprocessImage(_ image: UIImage) -> CVPixelBuffer? {
        let targetSize = CGSize(width: 224, height: 224)
        
        // Resize image to exactly 224x224 (stretch, matching PyTorch's Resize((224, 224)))
        // Create a bitmap context at exact pixel size (not points) to avoid scale factor issues
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipFirst.rawValue
        guard let resizeContext = CGContext(
            data: nil,
            width: 224,
            height: 224,
            bitsPerComponent: 8,
            bytesPerRow: 224 * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            print("❌ Failed to create bitmap context")
            return nil
        }
        
        // Draw the image into the context, stretching to exactly 224x224
        // PIL's Resize uses LANCZOS interpolation by default, but for exact matching
        // we should use high quality interpolation to match PyTorch's behavior
        resizeContext.interpolationQuality = .high // High quality interpolation to match PIL
        if let cgImage = image.cgImage {
            resizeContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: 224, height: 224))
        } else {
            print("❌ Failed to get CGImage from input image")
            return nil
        }
        
        guard let finalCGImage = resizeContext.makeImage() else {
            print("❌ Failed to create CGImage from context")
            return nil
        }
        
        print("🔍 Image preprocessing:")
        print("   Input size: \(image.size.width) x \(image.size.height)")
        print("   Final CGImage size: \(finalCGImage.width) x \(finalCGImage.height)")
        
        // Create CVPixelBuffer
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            224,
            224,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelBufferContext = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: 224,
            height: 224,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        guard let ctx = pixelBufferContext else {
            return nil
        }
        
        // CRITICAL: Core Graphics uses bottom-left origin, PIL uses top-left
        // We need to flip the Y-axis so that (0,0) in our buffer = top-left (like PIL/PyTorch)
        // When we read pixels row by row from y=0, we want the top row, not bottom row
        ctx.translateBy(x: 0, y: 224)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(finalCGImage, in: CGRect(x: 0, y: 0, width: 224, height: 224))
        
        return buffer
    }
    
    /// Normalize pixel buffer and convert to MLMultiArray
    /// Applies ImageNet normalization: (pixel / 255.0 - mean) / std
    private func normalizePixelBufferToArray(_ buffer: CVPixelBuffer) -> MLMultiArray? {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let baseAddress = CVPixelBufferGetBaseAddress(buffer)
        
        // ImageNet normalization constants
        let mean: [Float] = [0.485, 0.456, 0.406]
        let std: [Float] = [0.229, 0.224, 0.225]
        
        // Create MLMultiArray: shape [1, 3, 224, 224]
        guard let array = try? MLMultiArray(shape: [1, 3, 224, 224], dataType: .float32) else {
            return nil
        }
        
        // Extract and normalize each channel
        // PyTorch ToTensor() produces [C, H, W] with RGB channels in order [R, G, B]
        // After flipping Y-axis in drawing, y=0 in memory corresponds to visual top row
        // Our MLMultiArray is [batch, channel, height, width] = [1, 3, 224, 224]
        // Channel order: 0=R, 1=G, 2=B
        // IMPORTANT: After Y-flip, reading from y=0 gives us the top row (correct!)
        // CRITICAL: Read from bottom to top to account for Y-flip in drawing
        // The buffer was drawn with Y-flip, so y=0 in buffer = visual bottom row
        // We need to read from y=height-1 down to y=0 to get top-to-bottom order
        for visualY in 0..<height {
            let bufferY = height - 1 - visualY  // Read from bottom to top
            let row = baseAddress!.advanced(by: bufferY * bytesPerRow)
            for x in 0..<width {
                let pixel = row.assumingMemoryBound(to: UInt32.self)[x]
                
                // Extract RGB from ARGB format (32-bit: AAAAAAAA RRRRRRRR GGGGGGGG BBBBBBBB)
                // ARGB format: Alpha (bits 24-31), Red (bits 16-23), Green (bits 8-15), Blue (bits 0-7)
                let r = (pixel >> 16) & 0xFF
                let g = (pixel >> 8) & 0xFF
                let b = pixel & 0xFF
                
                // Convert to [0, 1] range (matching PyTorch ToTensor)
                let rFloat = Float(r) / 255.0
                let gFloat = Float(g) / 255.0
                let bFloat = Float(b) / 255.0
                
                // Apply ImageNet normalization: (pixel - mean) / std
                // This matches PyTorch: transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
                let rNorm = (rFloat - mean[0]) / std[0]
                let gNorm = (gFloat - mean[1]) / std[1]
                let bNorm = (bFloat - mean[2]) / std[2]
                
                // Store in MLMultiArray: [batch, channel, height, width]
                // PyTorch tensor is [C, H, W], we need [batch, C, H, W]
                // Index calculation: batch*C*H*W + channel*H*W + height*W + width
                // Use visualY (top-to-bottom) for correct ordering
                let rIdx = 0 * 3 * 224 * 224 + 0 * 224 * 224 + visualY * 224 + x
                let gIdx = 0 * 3 * 224 * 224 + 1 * 224 * 224 + visualY * 224 + x
                let bIdx = 0 * 3 * 224 * 224 + 2 * 224 * 224 + visualY * 224 + x
                
                array[rIdx] = NSNumber(value: rNorm)
                array[gIdx] = NSNumber(value: gNorm)
                array[bIdx] = NSNumber(value: bNorm)
            }
        }
        
        // Debug: Print sample values to verify preprocessing matches PyTorch
        // Compare these values with PyTorch output from test_preprocessing.py
        print("🔍 Preprocessing check - Sample normalized values:")
        
        // Calculate indices separately to avoid complex expressions
        let batchSize = 0
        let channels = 3
        let arrayHeight = 224
        let arrayWidth = 224
        let channelSize = arrayHeight * arrayWidth
        
        // Top-left pixel indices
        let topLeftRIdx = batchSize * channels * channelSize + 0 * channelSize + 0 * arrayWidth + 0
        let topLeftGIdx = batchSize * channels * channelSize + 1 * channelSize + 0 * arrayWidth + 0
        let topLeftBIdx = batchSize * channels * channelSize + 2 * channelSize + 0 * arrayWidth + 0
        
        let topLeftR = array[topLeftRIdx]
        let topLeftG = array[topLeftGIdx]
        let topLeftB = array[topLeftBIdx]
        print("   Top-left [0,0] - R: \(topLeftR), G: \(topLeftG), B: \(topLeftB)")
        
        // Center pixel indices
        let centerY = 112
        let centerX = 112
        let centerRIdx = batchSize * channels * channelSize + 0 * channelSize + centerY * arrayWidth + centerX
        let centerGIdx = batchSize * channels * channelSize + 1 * channelSize + centerY * arrayWidth + centerX
        let centerBIdx = batchSize * channels * channelSize + 2 * channelSize + centerY * arrayWidth + centerX
        
        let centerR = array[centerRIdx]
        let centerG = array[centerGIdx]
        let centerB = array[centerBIdx]
        print("   Center [112,112] - R: \(centerR), G: \(centerG), B: \(centerB)")
        
        // Check value ranges (should match PyTorch tensor range)
        var minR: Float = Float.greatestFiniteMagnitude
        var maxR: Float = -Float.greatestFiniteMagnitude
        var minG: Float = Float.greatestFiniteMagnitude
        var maxG: Float = -Float.greatestFiniteMagnitude
        var minB: Float = Float.greatestFiniteMagnitude
        var maxB: Float = -Float.greatestFiniteMagnitude
        
        let pixelCount = arrayHeight * arrayWidth
        for i in 0..<pixelCount {
            let y = i / arrayWidth
            let x = i % arrayWidth
            
            // Calculate indices for each channel
            let rBaseIdx = batchSize * channels * channelSize + 0 * channelSize
            let gBaseIdx = batchSize * channels * channelSize + 1 * channelSize
            let bBaseIdx = batchSize * channels * channelSize + 2 * channelSize
            
            let rIdx = rBaseIdx + y * arrayWidth + x
            let gIdx = gBaseIdx + y * arrayWidth + x
            let bIdx = bBaseIdx + y * arrayWidth + x
            
            let rVal = Float(truncating: array[rIdx])
            let gVal = Float(truncating: array[gIdx])
            let bVal = Float(truncating: array[bIdx])
            
            minR = min(minR, rVal)
            maxR = max(maxR, rVal)
            minG = min(minG, gVal)
            maxG = max(maxG, gVal)
            minB = min(minB, bVal)
            maxB = max(maxB, bVal)
        }
        print("   Value ranges - R: [\(minR), \(maxR)], G: [\(minG), \(maxG)], B: [\(minB), \(maxB)]")
        print("   Expected range: approximately [-2.1, 2.6] (ImageNet normalization)")
        
        return array
    }
    
    /// Extract landmarks from MLMultiArray and convert to pixel coordinates
    private func extractLandmarks(from multiArray: MLMultiArray, originalImageSize: CGSize) -> [(x: Double, y: Double)] {
        // MultiArray contains 96 values: [x1, y1, x2, y2, ..., x48, y48]
        // Values are normalized to [0, 1], need to scale to original image size
        var landmarks: [(x: Double, y: Double)] = []
        
        let count = multiArray.count
        guard count == 96 else {
            print("⚠️  Expected 96 values, got \(count)")
            return []
        }
        
            // Debug: Print first few values to verify format
            print("🔍 Model output - First 6 values: \(multiArray[0]), \(multiArray[1]), \(multiArray[2]), \(multiArray[3]), \(multiArray[4]), \(multiArray[5])")
            print("🔍 Original image size: \(originalImageSize.width) x \(originalImageSize.height)")
            print("🔍 Output range check - min: \(multiArray[0]), max: \(multiArray[multiArray.count - 1])")
            
            for i in 0..<48 {
                let xIdx = i * 2
                let yIdx = i * 2 + 1
                
                // Get normalized coordinates [0, 1]
                let xNorm = Double(truncating: multiArray[xIdx])
                let yNorm = Double(truncating: multiArray[yIdx])
                
                // Clamp to valid range (model outputs sigmoid, should be [0, 1] but might have slight overflow)
                let xNormClamped = max(0.0, min(1.0, xNorm))
                let yNormClamped = max(0.0, min(1.0, yNorm))
                
                // Convert to pixel coordinates
                // Note: Model was trained with landmarks normalized to original image size
                // So we multiply by original image dimensions
                let x = xNormClamped * Double(originalImageSize.width)
                let y = yNormClamped * Double(originalImageSize.height)
                
                landmarks.append((x: x, y: y))
            }
            
            // Debug: Print sample landmarks
            if landmarks.count >= 5 {
                print("🔍 Sample landmarks (first 5):")
                for i in 0..<5 {
                    print("   Landmark \(i): (\(landmarks[i].x), \(landmarks[i].y))")
                }
            }
        
        return landmarks
    }
    
}

// MARK: - Pain Score Calculator
class PainScoreCalculator {
    /// Calculate eye score based on landmark positions
    /// Returns: -1 (error), 0 (normal), 1 (mild), 2 (moderate/severe)
    static func calculateEyeScore(landmarks: [(x: Double, y: Double)]) -> Int {
        guard landmarks.count >= 12 else { return -1 }
        
        // Landmark indices (based on pain_scores.py):
        // Left eye: 8, 9, 10, 11
        // Right eye: 4, 5, 6, 7
        let leftEyeHorizontal = distance(landmarks[9], landmarks[8])
        let leftEyeVertical = distance(landmarks[10], landmarks[11])
        let rightEyeHorizontal = distance(landmarks[5], landmarks[4])
        let rightEyeVertical = distance(landmarks[7], landmarks[6])
        
        let rRatio = rightEyeVertical / max(rightEyeHorizontal, 1e-10)
        let lRatio = leftEyeVertical / max(leftEyeHorizontal, 1e-10)
        
        let minRatio = min(lRatio, rRatio)
        
        if minRatio > 1.0 { return -1 }
        else if minRatio > 0.7 { return 0 }
        else if minRatio >= 0.5 { return 1 }
        else { return 2 }
    }
    
    /// Calculate ear score based on landmark positions
    /// Returns: -1 (error), 0 (normal), 1 (mild), 2 (moderate/severe)
    static func calculateEarScore(landmarks: [(x: Double, y: Double)]) -> Int {
        guard landmarks.count >= 32 else { return -1 }
        
        // Calculate ear angles (based on pain_scores.py)
        // Right ear: 25, 26, 27
        // Left ear: 26, 27, 28
        let rEarA = subtract(landmarks[25], landmarks[26])
        let rEarB = subtract(landmarks[27], landmarks[26])
        let rEarAngle = angleBetween(rEarA, rEarB)
        
        let lEarA = subtract(landmarks[28], landmarks[27])
        let lEarB = subtract(landmarks[26], landmarks[27])
        let lEarAngle = angleBetween(lEarA, lEarB)
        
        // Vertical angles
        let earBaseLine = subtract(landmarks[31], landmarks[22])
        let lEarVertical = subtract(landmarks[31], landmarks[30])
        let rEarVertical = subtract(landmarks[22], landmarks[23])
        
        let lVertAngle = angleBetween(earBaseLine, lEarVertical)
        let rVertAngle = angleBetween(earBaseLine, rEarVertical)
        
        let minEarAngle = min(lEarAngle, rEarAngle)
        let maxVertAngle = max(lVertAngle, rVertAngle)
        
        if max(lEarAngle, rEarAngle) < 115 { return -1 }
        if minEarAngle > 145 || maxVertAngle < 70 { return 2 }
        if (115...125).contains(minEarAngle) || maxVertAngle > 75 { return 0 }
        return 1
    }
    
    /// Calculate muzzle score based on landmark positions
    /// Returns: -1 (error), 0 (normal), 1 (mild), 2 (moderate/severe)
    static func calculateMuzzleScore(landmarks: [(x: Double, y: Double)]) -> Int {
        guard landmarks.count >= 46 else { return -1 }
        
        // Muzzle measurements (based on pain_scores.py)
        let lMuzzleWidth = distance(landmarks[44], landmarks[32])
        let rMuzzleWidth = distance(landmarks[45], landmarks[35])
        let lMuzzleHeight = distance(landmarks[42], landmarks[21])
        let rMuzzleHeight = distance(landmarks[43], landmarks[19])
        
        let lMuzzleRatio = lMuzzleWidth / max(lMuzzleHeight, 1e-10)
        let rMuzzleRatio = rMuzzleWidth / max(rMuzzleHeight, 1e-10)
        
        let maxRatio = max(lMuzzleRatio, rMuzzleRatio)
        
        if maxRatio > 2.0 { return 2 }
        else if maxRatio > 1.5 { return 1 }
        else if maxRatio < 0.8 { return -1 }
        else { return 0 }
    }
    
    /// Calculate all pain scores
    static func calculatePainScores(landmarks: [(x: Double, y: Double)]) -> (eye: Int, ear: Int, muzzle: Int) {
        let eyeScore = calculateEyeScore(landmarks: landmarks)
        let earScore = calculateEarScore(landmarks: landmarks)
        let muzzleScore = calculateMuzzleScore(landmarks: landmarks)
        
        return (eye: eyeScore, ear: earScore, muzzle: muzzleScore)
    }
}

// MARK: - Helper Functions
private func distance(_ p1: (x: Double, y: Double), _ p2: (x: Double, y: Double)) -> Double {
    let dx = p1.x - p2.x
    let dy = p1.y - p2.y
    return sqrt(dx * dx + dy * dy)
}

private func subtract(_ p1: (x: Double, y: Double), _ p2: (x: Double, y: Double)) -> (x: Double, y: Double) {
    return (x: p1.x - p2.x, y: p1.y - p2.y)
}

private func angleBetween(_ v1: (x: Double, y: Double), _ v2: (x: Double, y: Double)) -> Double {
    let dot = v1.x * v2.x + v1.y * v2.y
    let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
    let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
    let cosAngle = dot / max(mag1 * mag2, 1e-10)
    let angle = acos(max(-1.0, min(1.0, cosAngle))) // Clamp to [-1, 1] for acos
    return angle * 180.0 / .pi // Convert to degrees
}


// MARK: - UIImage Extension
extension UIImage {
    /// Fix image orientation to .up (matching PIL's behavior)
    /// PIL automatically handles EXIF orientation when loading images
    func fixedOrientation() -> UIImage {
        // If already in correct orientation, return as-is
        if imageOrientation == .up {
            return self
        }
        
        // Calculate the transform needed to fix orientation
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.width)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        // Create a new image with fixed orientation
        guard let cgImage = self.cgImage else {
            return self
        }
        
        let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue
        )
        
        guard let context = ctx else {
            return self
        }
        
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        guard let cgImageFixed = context.makeImage() else {
            return self
        }
        
        return UIImage(cgImage: cgImageFixed, scale: scale, orientation: .up)
    }
    
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

