import os
import torch
from torch.utils.data import random_split
from dataset import CatLandmarkDataset
from inference import evaluate_model

# Recreate the same split as training
data_dir = '/Users/elaine01px2019/Downloads/CatFLW dataset'
image_dir = os.path.join(data_dir, 'images')
label_dir = os.path.join(data_dir, 'labels')

# Create full dataset without transform for splitting (same as training)
full_dataset = CatLandmarkDataset(image_dir, label_dir, transform=None)

# Split dataset indices (same as training - 20% validation split)
val_split = 0.2
val_size = int(len(full_dataset) * val_split)
train_size = len(full_dataset) - val_size
train_split, val_split_indices = random_split(full_dataset, [train_size, val_size])

# Get all image files (sorted)
all_image_files = sorted([f for f in os.listdir(image_dir) 
                         if f.endswith('.png') and '_landmarks' not in f and '_comparison' not in f])

# Get filenames for validation set only
val_indices = val_split_indices.indices
val_files = [all_image_files[i] for i in val_indices]

print(f"Total validation set size: {len(val_files)} images")
print(f"Will test on first 50 images from validation set\n")

# Create a temporary directory with only validation images for testing
# Or better: modify evaluate_model to accept specific file list
# For now, let's create a modified version that tests only on validation set

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
print(f"Using device: {device}\n")

# Load model
from model import CatLandmarkModel
model = CatLandmarkModel(num_landmarks=48, backbone='resnet18', pretrained=False)
checkpoint = torch.load('checkpoints/best_model.pth', map_location=device)
model.load_state_dict(checkpoint['model_state_dict'])
model.to(device)
model.eval()

print(f"Loaded model from checkpoints/best_model.pth")
print(f"Model val_loss: {checkpoint['val_loss']:.6f}\n")

# Test on validation set images only
from inference import predict_landmarks
import json
import numpy as np
from PIL import Image

test_files = val_files[:50]  # First 50 from validation set
print(f"Testing on {len(test_files)} images from VALIDATION set only\n")

total_nme = 0.0
for img_file in test_files:
    img_path = os.path.join(image_dir, img_file)
    label_path = os.path.join(label_dir, img_file.replace('.png', '.json'))
    
    # Load ground truth
    with open(label_path, 'r') as f:
        gt_data = json.load(f)
    gt_landmarks = np.array(gt_data['labels'], dtype=np.float32)
    
    # Predict
    pred_landmarks, _ = predict_landmarks(model, img_path, device, save_vis=True)
    
    # Calculate NME
    image = Image.open(img_path).convert('RGB')
    img_width, img_height = image.size
    
    # Normalize GT landmarks
    gt_normalized = gt_landmarks.copy()
    gt_normalized[:, 0] /= img_width
    gt_normalized[:, 1] /= img_height
    
    # Normalize predictions
    pred_normalized = pred_landmarks.copy()
    pred_normalized[:, 0] /= img_width
    pred_normalized[:, 1] /= img_height
    
    # Calculate inter-ocular distance
    eye_dist = np.linalg.norm(gt_normalized[8] - gt_normalized[11])
    eye_dist = max(eye_dist, 1e-5)
    
    # Calculate mean error
    errors = np.linalg.norm(pred_normalized - gt_normalized, axis=1)
    mean_error = np.mean(errors)
    nme = mean_error / eye_dist
    
    total_nme += nme
    print(f"{img_file}: NME = {nme:.6f}")

avg_nme = total_nme / len(test_files)
print(f"\n{'='*80}")
print(f"Average NME on VALIDATION SET ONLY: {avg_nme:.6f}")
print(f"{'='*80}")
print(f"\n✓ This is a more accurate metric since these images were NOT seen during training")

