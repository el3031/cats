import os
import torch
import json
import numpy as np
from PIL import Image
from torchvision import transforms
import matplotlib.pyplot as plt
import matplotlib.patches as patches

from model import CatLandmarkModel


def visualize_landmarks(image_path, landmarks, save_path=None):
    """Visualize landmarks on the image"""
    # Load image
    img = Image.open(image_path).convert('RGB')
    img_array = np.array(img)
    
    # Create figure
    fig, ax = plt.subplots(1, 1, figsize=(12, 12))
    ax.imshow(img_array)
    ax.axis('off')
    
    # Plot landmarks
    ax.scatter(landmarks[:, 0], landmarks[:, 1], c='red', s=50, marker='o', edgecolors='white', linewidths=1)
    
    # Connect key points (optional - customize based on landmark structure)
    # Connect eyes, nose, mouth, etc.
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, bbox_inches='tight', dpi=150)
        print(f"Saved visualization to {save_path}")
    else:
        plt.show()
    
    plt.close()


def predict_landmarks(model, image_path, device, img_size=(224, 224), save_vis=False):
    """
    Predict landmarks for a single image
    
    Args:
        model: Trained model
        image_path: Path to input image
        device: torch device
        img_size: Input image size for model
        save_vis: Whether to save visualization
    
    Returns:
        landmarks: Array of shape (47, 2) with normalized [0, 1] coordinates
    """
    # Load and preprocess image
    image = Image.open(image_path).convert('RGB')
    original_size = image.size  # (width, height)
    
    # Transform
    transform = transforms.Compose([
        transforms.Resize(img_size),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    img_tensor = transform(image).unsqueeze(0).to(device)
    
    # Predict
    model.eval()
    with torch.no_grad():
        predictions = model(img_tensor)
    
    # Reshape to (num_landmarks, 2)
    landmarks_normalized = predictions.cpu().numpy().reshape(48, 2)
    
    # Denormalize to original image coordinates
    landmarks = landmarks_normalized.copy()
    landmarks[:, 0] *= original_size[0]  # x coordinates
    landmarks[:, 1] *= original_size[1]  # y coordinates
    
    # Visualize if requested
    if save_vis:
        vis_path = image_path.replace('.png', '_landmarks.png').replace('.jpg', '_landmarks.jpg')
        visualize_landmarks(image_path, landmarks, vis_path)
    
    return landmarks, landmarks_normalized


def evaluate_model(model, test_data_dir, device, num_samples=10):
    """Evaluate model on test images"""
    image_dir = os.path.join(test_data_dir, 'images')
    label_dir = os.path.join(test_data_dir, 'labels')
    
    # Get only actual image files, exclude _landmarks.png files
    image_files = sorted([f for f in os.listdir(image_dir) 
                         if f.endswith('.png') and not f.endswith('_landmarks.png') and not f.endswith('_comparison.png')])[:num_samples]
    
    total_nme = 0.0
    
    for img_file in image_files:
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
        
        # Calculate inter-ocular distance
        eye_dist = np.linalg.norm(gt_normalized[8] - gt_normalized[11])
        eye_dist = max(eye_dist, 1e-5)  # Avoid division by zero
        
        # Calculate mean error
        pred_normalized = pred_landmarks.copy()
        pred_normalized[:, 0] /= img_width
        pred_normalized[:, 1] /= img_height
        
        errors = np.linalg.norm(pred_normalized - gt_normalized, axis=1)
        mean_error = np.mean(errors)
        nme = mean_error / eye_dist
        
        total_nme += nme
        print(f"{img_file}: NME = {nme:.6f}")
    
    avg_nme = total_nme / len(image_files)
    print(f"\nAverage NME: {avg_nme:.6f}")
    
    return avg_nme


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Cat Facial Landmark Detection - Inference')
    parser.add_argument('--image', type=str, help='Path to input image')
    parser.add_argument('--model', type=str, default='checkpoints/best_model.pth', help='Path to model checkpoint')
    parser.add_argument('--test_dir', type=str, default=None, help='Directory to test on multiple images')
    parser.add_argument('--backbone', type=str, default='resnet18', help='Model backbone')
    parser.add_argument('--device', type=str, default='auto', help='Device (auto, cuda, cpu)')
    
    args = parser.parse_args()
    
    # Set device
    if args.device == 'auto':
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    else:
        device = torch.device(args.device)
    
    print(f"Using device: {device}")
    
    # Load model
    model = CatLandmarkModel(num_landmarks=48, backbone=args.backbone, pretrained=False)
    
    if os.path.exists(args.model):
        checkpoint = torch.load(args.model, map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        print(f"Loaded model from {args.model}")
        if 'val_loss' in checkpoint:
            print(f"Model val_loss: {checkpoint['val_loss']:.6f}")
    else:
        print(f"Warning: Model file {args.model} not found. Using untrained model.")
    
    model = model.to(device)
    model.eval()
    
    # Predict on single image or evaluate on test set
    if args.image:
        landmarks, landmarks_norm = predict_landmarks(model, args.image, device, save_vis=True)
        print(f"\nPredicted {len(landmarks)} landmarks")
        print(f"Landmark coordinates (pixels):")
        for i, (x, y) in enumerate(landmarks):
            print(f"  Landmark {i}: ({x:.2f}, {y:.2f})")
    
    elif args.test_dir:
        evaluate_model(model, args.test_dir, device, num_samples=50)
    
    else:
        print("Please provide either --image or --test_dir argument")
        parser.print_help()


if __name__ == '__main__':
    main()

