"""Compare ground truth and predictions side by side"""

import torch
import json
import numpy as np
from PIL import Image
from torchvision import transforms
import matplotlib.pyplot as plt

from model import CatLandmarkModel
from inference import visualize_landmarks


def compare_prediction_gt(image_path, label_path, model, device):
    """Compare prediction vs ground truth"""
    # Load image and GT
    img = Image.open(image_path).convert('RGB')
    with open(label_path, 'r') as f:
        gt_data = json.load(f)
    gt_landmarks = np.array(gt_data['labels'], dtype=np.float32)
    
    # Predict
    original_size = img.size
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    img_tensor = transform(img).unsqueeze(0).to(device)
    
    model.eval()
    with torch.no_grad():
        predictions = model(img_tensor)
    
    # Reshape predictions
    landmarks_normalized = predictions.cpu().numpy().reshape(48, 2)
    pred_landmarks = landmarks_normalized.copy()
    pred_landmarks[:, 0] *= original_size[0]
    pred_landmarks[:, 1] *= original_size[1]
    
    # Create comparison visualization
    fig, axes = plt.subplots(1, 2, figsize=(20, 10))
    
    # Ground truth
    img_array = np.array(img)
    axes[0].imshow(img_array)
    axes[0].scatter(gt_landmarks[:, 0], gt_landmarks[:, 1], c='green', s=30, marker='o', edgecolors='white', linewidths=1)
    axes[0].set_title('Ground Truth', fontsize=16)
    axes[0].axis('off')
    
    # Prediction
    axes[1].imshow(img_array)
    axes[1].scatter(pred_landmarks[:, 0], pred_landmarks[:, 1], c='red', s=30, marker='o', edgecolors='white', linewidths=1)
    axes[1].set_title('Prediction', fontsize=16)
    axes[1].axis('off')
    
    plt.tight_layout()
    
    # Save
    save_path = image_path.replace('.png', '_comparison.png')
    plt.savefig(save_path, bbox_inches='tight', dpi=150)
    print(f"Saved comparison to {save_path}")
    plt.close()


if __name__ == '__main__':
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python compare_predictions.py <image_path>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    label_path = image_path.replace('/images/', '/labels/').replace('.png', '.json')
    
    # Load model
    device = torch.device('cpu')
    model = CatLandmarkModel(num_landmarks=48, pretrained=False)
    checkpoint = torch.load('checkpoints/best_model.pth', map_location=device)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.to(device)
    model.eval()
    
    compare_prediction_gt(image_path, label_path, model, device)

