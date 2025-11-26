"""
Convert PyTorch Cat Landmark Model to Core ML format for iOS

Usage:
    python convert_to_coreml.py --model checkpoints/best_model.pth --output CatLandmarkModel.mlpackage
    
    # Or use NeuralNetwork format (older):
    python convert_to_coreml.py --model checkpoints/best_model.pth --output CatLandmarkModel.mlmodel --format neuralnetwork
"""

import torch
import coremltools as ct
import numpy as np
from PIL import Image
from model import CatLandmarkModel
import argparse
import os

def convert_to_coreml(model_path, output_path, backbone='resnet18', format='mlprogram'):
    """
    Convert PyTorch model to Core ML format
    
    Args:
        model_path: Path to PyTorch checkpoint (.pth file)
        output_path: Output path for .mlpackage or .mlmodel file
        backbone: Model backbone architecture
        format: Core ML format ('mlprogram' for .mlpackage or 'neuralnetwork' for .mlmodel)
    """
    print(f"Loading PyTorch model from {model_path}...")
    
    # Load model
    device = torch.device('cpu')  # Core ML conversion requires CPU
    model = CatLandmarkModel(num_landmarks=48, backbone=backbone, pretrained=False)
    
    if os.path.exists(model_path):
        checkpoint = torch.load(model_path, map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        print(f"✅ Loaded model from {model_path}")
        if 'val_loss' in checkpoint:
            print(f"   Model val_loss: {checkpoint['val_loss']:.6f}")
    else:
        raise FileNotFoundError(f"Model file not found: {model_path}")
    
    model.eval()
    
    # Create example input (224x224 RGB image)
    example_input = torch.randn(1, 3, 224, 224)
    
    print("\nConverting to Core ML...")
    
    # Trace the model
    traced_model = torch.jit.trace(model, example_input)
    
    # Convert to Core ML
    # Input: RGB image, 224x224, normalized with ImageNet stats
    # Output: 96 values (48 landmarks × 2 coordinates), normalized to [0, 1]
    # Note: Newer coremltools creates ML Program format (.mlpackage) by default
    # We can use convert_to="neuralnetwork" for .mlmodel, or use .mlpackage (recommended)
    print(f"Converting to Core ML format: {format}")
    
    # Convert using TensorType (model expects tensor input, not image)
    # We'll handle preprocessing manually in Swift to match PyTorch exactly
    # CRITICAL: Use FLOAT32 precision to match PyTorch exactly
    mlmodel = ct.convert(
        traced_model,
        inputs=[ct.TensorType(name="image", shape=example_input.shape)],
        outputs=[ct.TensorType(name="landmarks")],
        compute_units=ct.ComputeUnit.ALL,
        convert_to=format,
        compute_precision=ct.precision.FLOAT32,  # Match PyTorch's float32 precision
    )
    print("✅ Converted using TensorType input")
    
    # Add ImageNet normalization preprocessing
    # The model expects: (pixel / 255.0 - mean) / std
    # mean = [0.485, 0.456, 0.406], std = [0.229, 0.224, 0.225]
    # Note: For production, consider using ImageType input with built-in normalization
    
    # Add metadata
    mlmodel.author = "Cat Pain Analysis"
    mlmodel.short_description = "Cat facial landmark detection model for pain analysis"
    mlmodel.version = "1.0"
    mlmodel.input_description["image"] = "RGB image of cat face, 224x224 pixels"
    mlmodel.output_description["landmarks"] = "48 facial landmarks as normalized coordinates [0, 1], shape (96,) - flattened [x1, y1, x2, y2, ..., x48, y48]"
    
    # Save the model
    mlmodel.save(output_path)
    print(f"\n✅ Core ML model saved to: {output_path}")
    print(f"   Model size: {os.path.getsize(output_path) / (1024 * 1024):.2f} MB")
    
    # Test the conversion
    print("\nTesting Core ML model...")
    try:
        test_input = example_input.numpy()
        coreml_output = mlmodel.predict({"image": test_input})
        landmarks = coreml_output["landmarks"]
        
        # Handle both numpy array and MLMultiArray outputs
        if hasattr(landmarks, 'shape'):
            landmarks_array = landmarks
        else:
            # Convert MLMultiArray to numpy if needed
            import numpy as np
            landmarks_array = np.array(landmarks).flatten()
        
        print(f"   Input shape: {test_input.shape}")
        print(f"   Output shape: {landmarks_array.shape}")
        print(f"   Output range: [{landmarks_array.min():.4f}, {landmarks_array.max():.4f}]")
        print(f"   Expected range: [0, 1] (sigmoid output)")
    except Exception as e:
        print(f"   ⚠️  Could not test model (this is okay): {e}")
    
    return mlmodel


def main():
    parser = argparse.ArgumentParser(description='Convert PyTorch model to Core ML')
    parser.add_argument('--model', type=str, default='checkpoints/best_model.pth',
                        help='Path to PyTorch checkpoint')
    parser.add_argument('--output', type=str, default='CatLandmarkModel.mlpackage',
                        help='Output path for Core ML model (.mlpackage for ML Program, .mlmodel for NeuralNetwork)')
    parser.add_argument('--backbone', type=str, default='resnet18',
                        help='Model backbone (resnet18, resnet34, resnet50)')
    parser.add_argument('--format', type=str, default='mlprogram', choices=['mlprogram', 'neuralnetwork'],
                        help='Core ML format: mlprogram (.mlpackage) or neuralnetwork (.mlmodel)')
    
    args = parser.parse_args()
    
    # Check if model exists
    if not os.path.exists(args.model):
        print(f"❌ Error: Model file not found: {args.model}")
        print("   Please train a model first or provide the correct path.")
        return
    
    # Validate output extension matches format
    if args.format == 'mlprogram' and not args.output.endswith('.mlpackage'):
        print(f"⚠️  Warning: ML Program format requires .mlpackage extension")
        print(f"   Changing output from {args.output} to {args.output.replace('.mlmodel', '.mlpackage')}")
        args.output = args.output.replace('.mlmodel', '.mlpackage')
    elif args.format == 'neuralnetwork' and not args.output.endswith('.mlmodel'):
        print(f"⚠️  Warning: NeuralNetwork format requires .mlmodel extension")
        print(f"   Changing output from {args.output} to {args.output.replace('.mlpackage', '.mlmodel')}")
        args.output = args.output.replace('.mlpackage', '.mlmodel')
    
    try:
        convert_to_coreml(args.model, args.output, args.backbone, args.format)
        print("\n🎉 Conversion successful!")
        print(f"\nNext steps:")
        print(f"1. Add {args.output} to your Xcode project")
        print(f"2. Xcode will automatically generate a Swift class for the model")
        print(f"3. Use the model in your Swift code (see ProcessingView.swift)")
    except Exception as e:
        print(f"\n❌ Error during conversion: {e}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()

