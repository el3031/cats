import torch
import json
import numpy as np
from PIL import Image
from torchvision import transforms
from model import CatLandmarkModel

# Load model
device = torch.device('cpu')
model = CatLandmarkModel(num_landmarks=48, backbone='resnet18', pretrained=False)
checkpoint = torch.load('checkpoints/best_model.pth', map_location=device)
model.load_state_dict(checkpoint['model_state_dict'])
model.to(device)
model.eval()

# Test image
image_path = "/Users/elaine01px2019/Downloads/CatFLW dataset/images/00000001_000.png"
label_path = "/Users/elaine01px2019/Downloads/CatFLW dataset/labels/00000001_000.json"

# Load image
image = Image.open(image_path).convert('RGB')
original_size = image.size  # (width, height)
print(f"Original image size: {original_size}")

# Load ground truth
with open(label_path, 'r') as f:
    gt_data = json.load(f)
gt_landmarks = np.array(gt_data['labels'], dtype=np.float32)
print(f"GT landmarks shape: {gt_landmarks.shape}")
print(f"GT landmarks range: x=[{gt_landmarks[:, 0].min():.2f}, {gt_landmarks[:, 0].max():.2f}], y=[{gt_landmarks[:, 1].min():.2f}, {gt_landmarks[:, 1].max():.2f}]")

# Normalize GT for comparison
gt_normalized = gt_landmarks.copy()
gt_normalized[:, 0] /= original_size[0]
gt_normalized[:, 1] /= original_size[1]
print(f"GT normalized range: x=[{gt_normalized[:, 0].min():.4f}, {gt_normalized[:, 0].max():.4f}], y=[{gt_normalized[:, 1].min():.4f}, {gt_normalized[:, 1].max():.4f}]")

# Transform and predict
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

img_tensor = transform(image).unsqueeze(0).to(device)

with torch.no_grad():
    predictions = model(img_tensor)

# Reshape predictions
pred_landmarks_normalized = predictions.cpu().numpy().reshape(48, 2)
print(f"\nPredicted landmarks (normalized) shape: {pred_landmarks_normalized.shape}")
print(f"Predicted normalized range: x=[{pred_landmarks_normalized[:, 0].min():.4f}, {pred_landmarks_normalized[:, 0].max():.4f}], y=[{pred_landmarks_normalized[:, 1].min():.4f}, {pred_landmarks_normalized[:, 1].max():.4f}]")

# Denormalize predictions
pred_landmarks = pred_landmarks_normalized.copy()
pred_landmarks[:, 0] *= original_size[0]
pred_landmarks[:, 1] *= original_size[1]
print(f"Predicted landmarks (pixels) range: x=[{pred_landmarks[:, 0].min():.2f}, {pred_landmarks[:, 0].max():.2f}], y=[{pred_landmarks[:, 1].min():.2f}, {pred_landmarks[:, 1].max():.2f}]")

# Calculate error
errors = np.linalg.norm(pred_landmarks_normalized - gt_normalized, axis=1)
print(f"\nMean error (normalized): {np.mean(errors):.6f}")
print(f"Max error (normalized): {np.max(errors):.6f}")

# Check if predictions are outside [0,1]
out_of_range = (pred_landmarks_normalized < 0) | (pred_landmarks_normalized > 1)
if np.any(out_of_range):
    print(f"\nWARNING: {np.sum(out_of_range)} predictions are outside [0,1] range!")
    print(f"Out of range indices: {np.where(out_of_range)[0]}")
else:
    print("\nAll predictions are in [0,1] range")

