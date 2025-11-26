"""
Test script to verify preprocessing matches between PyTorch and what we're doing in Swift
"""

import torch
import numpy as np
from PIL import Image
from torchvision import transforms

# Create a test image (or use a real one)
# For testing, create a simple colored image
test_image = Image.new('RGB', (300, 400), color='red')
# Or load a real image:
# test_image = Image.open('path/to/image.jpg').convert('RGB')

original_size = test_image.size
print(f"Original image size: {original_size}")

# PyTorch preprocessing (exactly as in inference.py)
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

img_tensor = transform(test_image)
print(f"\nTensor shape: {img_tensor.shape}")  # Should be [3, 224, 224]
print(f"Tensor dtype: {img_tensor.dtype}")

# Check first pixel values
print(f"\nFirst pixel (top-left) normalized values:")
print(f"  R channel: {img_tensor[0, 0, 0]:.6f}")
print(f"  G channel: {img_tensor[1, 0, 0]:.6f}")
print(f"  B channel: {img_tensor[2, 0, 0]:.6f}")

# Check center pixel
print(f"\nCenter pixel (112, 112) normalized values:")
print(f"  R channel: {img_tensor[0, 112, 112]:.6f}")
print(f"  G channel: {img_tensor[1, 112, 112]:.6f}")
print(f"  B channel: {img_tensor[2, 112, 112]:.6f}")

# Check value ranges
print(f"\nValue ranges:")
print(f"  R: min={img_tensor[0].min():.6f}, max={img_tensor[0].max():.6f}")
print(f"  G: min={img_tensor[1].min():.6f}, max={img_tensor[1].max():.6f}")
print(f"  B: min={img_tensor[2].min():.6f}, max={img_tensor[2].max():.6f}")

# Verify channel order: PyTorch ToTensor produces [R, G, B]
print(f"\nChannel order verification:")
print(f"  Channel 0 should be R (Red)")
print(f"  Channel 1 should be G (Green)")
print(f"  Channel 2 should be B (Blue)")

# For a red image, R should be highest
if img_tensor[0].mean() > img_tensor[1].mean() and img_tensor[0].mean() > img_tensor[2].mean():
    print("  ✓ Channel order appears correct (R, G, B)")
else:
    print("  ⚠ Channel order might be wrong!")

