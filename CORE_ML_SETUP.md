# Core ML Setup Guide

This guide explains how to convert your PyTorch cat landmark detection model to Core ML and use it in your iOS app.

## Overview

Core ML is Apple's framework for running machine learning models on-device. It's much more efficient than running Python/PyTorch on iOS because:
- ✅ Native iOS support (no Python runtime needed)
- ✅ Smaller app size (~10-50MB vs 500MB+ for PyTorch)
- ✅ Better performance (uses Neural Engine, GPU, CPU)
- ✅ Works offline
- ✅ Better privacy (all processing on-device)

## Step 1: Install Core ML Tools

First, install the required Python package:

```bash
pip install coremltools
```

## Step 2: Convert PyTorch Model to Core ML

Run the conversion script:

```bash
python convert_to_coreml.py --model checkpoints/best_model.pth --output CatLandmarkModel.mlmodel
```

This will:
1. Load your trained PyTorch model
2. Convert it to Core ML format
3. Save it as `CatLandmarkModel.mlmodel`

**Note:** Make sure you have a trained model checkpoint at `checkpoints/best_model.pth`. If your model is in a different location, specify it with `--model`.

## Step 3: Add Model to Xcode Project

1. Open your Xcode project
2. Drag `CatLandmarkModel.mlmodel` into your project (under the `Moodle` folder)
3. Make sure "Copy items if needed" is checked
4. Make sure it's added to the "Moodle" target

Xcode will automatically:
- Compile the model (creates `.mlmodelc` file)
- Generate a Swift class for the model
- Validate the model

## Step 4: Verify Model in Xcode

1. Click on `CatLandmarkModel.mlmodel` in Xcode
2. You should see:
   - **Input:** `image` - 3 × 224 × 224 (RGB image)
   - **Output:** `landmarks` - 96 values (48 landmarks × 2 coordinates)

## Step 5: Test the App

The app is already set up to use Core ML! When you run it:

1. Take a photo of a cat
2. Navigate to the Processing view
3. The app will:
   - Load the Core ML model
   - Predict 48 facial landmarks
   - Calculate pain scores (eye, ear, muzzle)
   - Log results to console

## Troubleshooting

### Model Not Found Error

If you see: `⚠️ Core ML model not found in bundle`

**Solution:**
1. Make sure `CatLandmarkModel.mlmodel` is in your Xcode project
2. Check that it's added to the "Moodle" target (Target Membership in File Inspector)
3. Clean build folder (Shift+Cmd+K) and rebuild

### Model Input/Output Mismatch

If the model expects different input/output shapes:

**Solution:**
1. Check your model architecture in `model.py`
2. Update the conversion script if needed
3. Re-run the conversion

### Poor Prediction Quality

If landmarks are inaccurate:

**Solution:**
1. Make sure the model was trained properly
2. Verify the input preprocessing matches training (ImageNet normalization)
3. Check that images are resized to 224×224 before inference

## Model Architecture

Your model:
- **Backbone:** ResNet18
- **Input:** 224×224 RGB image
- **Output:** 48 landmarks (96 values: x1, y1, x2, y2, ..., x48, y48)
- **Normalization:** ImageNet stats (mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
- **Output Range:** [0, 1] (sigmoid activation)

## Next Steps

After Core ML is working, you can:
1. Display pain scores in the UI (currently just logged to console)
2. Add visualization of landmarks on the image
3. Save results to Core Data
4. Add more sophisticated pain score interpretation

## Files Created

- `convert_to_coreml.py` - Conversion script
- `CoreMLInference.swift` - Swift wrapper for Core ML inference
- `ProcessingView.swift` - Updated to use Core ML instead of PythonKit

## Performance Notes

- **First inference:** ~100-200ms (model loading)
- **Subsequent inferences:** ~20-50ms (on Neural Engine)
- **Memory:** ~10-50MB (model size)
- **Battery:** Very efficient (uses Neural Engine when available)

