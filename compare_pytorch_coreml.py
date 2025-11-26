"""
Compare PyTorch and Core ML model outputs on the same image
This helps debug accuracy differences
"""

import torch
import coremltools as ct
import numpy as np
from PIL import Image
from torchvision import transforms
from model import CatLandmarkModel
import os

def compare_models(image_path, model_path='checkpoints/best_model.pth', coreml_path='CatLandmarkModel.mlpackage'):
    """Compare PyTorch and Core ML model outputs"""
    
    # Load image
    image = Image.open(image_path).convert('RGB')
    original_size = image.size
    print(f"Image: {image_path}")
    print(f"Original size: {original_size}")
    
    # PyTorch preprocessing
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    img_tensor = transform(image).unsqueeze(0)
    print(f"\nPyTorch tensor shape: {img_tensor.shape}")
    print(f"PyTorch tensor range: [{img_tensor.min():.4f}, {img_tensor.max():.4f}]")
    
    # Load PyTorch model
    device = torch.device('cpu')
    pytorch_model = CatLandmarkModel(num_landmarks=48, backbone='resnet18', pretrained=False)
    checkpoint = torch.load(model_path, map_location=device)
    pytorch_model.load_state_dict(checkpoint['model_state_dict'])
    pytorch_model.eval()
    
    # PyTorch prediction
    with torch.no_grad():
        pytorch_output = pytorch_model(img_tensor)
    
    pytorch_landmarks = pytorch_output.cpu().numpy().reshape(48, 2)
    print(f"\nPyTorch output shape: {pytorch_landmarks.shape}")
    print(f"PyTorch output range: [{pytorch_landmarks.min():.4f}, {pytorch_landmarks.max():.4f}]")
    print(f"First 5 landmarks: {pytorch_landmarks[:5]}")
    
    # Load Core ML model
    if not os.path.exists(coreml_path):
        print(f"\n❌ Core ML model not found: {coreml_path}")
        print("   Run: python convert_to_coreml.py")
        return
    
    coreml_model = ct.models.MLModel(coreml_path)
    
    # Prepare input for Core ML (same as PyTorch)
    # Convert tensor to numpy and reshape to [1, 3, 224, 224]
    coreml_input = {"image": img_tensor.numpy()}
    
    # Core ML prediction
    coreml_output = coreml_model.predict(coreml_input)
    coreml_landmarks = coreml_output["landmarks"].reshape(48, 2)
    
    print(f"\nCore ML output shape: {coreml_landmarks.shape}")
    print(f"Core ML output range: [{coreml_landmarks.min():.4f}, {coreml_landmarks.max():.4f}]")
    print(f"First 5 landmarks: {coreml_landmarks[:5]}")
    
    # Compare
    diff = np.abs(pytorch_landmarks - coreml_landmarks)
    print(f"\n📊 Comparison:")
    print(f"   Mean absolute difference: {diff.mean():.6f}")
    print(f"   Max absolute difference: {diff.max():.6f}")
    print(f"   Differences per landmark:")
    for i in range(min(10, 48)):
        print(f"     Landmark {i}: PyTorch={pytorch_landmarks[i]}, CoreML={coreml_landmarks[i]}, Diff={diff[i]}")
    
    # Convert to pixel coordinates
    pytorch_pixels = pytorch_landmarks.copy()
    pytorch_pixels[:, 0] *= original_size[0]
    pytorch_pixels[:, 1] *= original_size[1]
    
    coreml_pixels = coreml_landmarks.copy()
    coreml_pixels[:, 0] *= original_size[0]
    coreml_pixels[:, 1] *= original_size[1]
    
    pixel_diff = np.abs(pytorch_pixels - coreml_pixels)
    print(f"\n📏 Pixel coordinate differences:")
    print(f"   Mean: {pixel_diff.mean():.2f} pixels")
    print(f"   Max: {pixel_diff.max():.2f} pixels")
    
    if pixel_diff.mean() < 1.0:
        print("✅ Models are very close!")
    elif pixel_diff.mean() < 5.0:
        print("⚠️  Models have moderate differences")
    else:
        print("❌ Models have significant differences - check preprocessing!")

if __name__ == '__main__':
    import sys
    if len(sys.argv) > 1:
        image_path = sys.argv[1]
    else:
        image_path = "/Users/elaine01px2019/Downloads/CatFLW dataset/images/00000001_000.png"
    
    compare_models(image_path)

