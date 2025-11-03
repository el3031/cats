import os
import json
import torch
from torch.utils.data import Dataset
from PIL import Image
import numpy as np
from torchvision import transforms


class CatLandmarkDataset(Dataset):
    """Dataset class for Cat Facial Landmark Detection"""
    
    def __init__(self, image_dir, label_dir, transform=None, normalize_landmarks=True):
        """
        Args:
            image_dir: Path to directory containing cat images
            label_dir: Path to directory containing JSON label files
            transform: Optional torchvision transforms to apply
            normalize_landmarks: If True, normalize landmarks to [0, 1] range
        """
        self.image_dir = image_dir
        self.label_dir = label_dir
        self.transform = transform
        self.normalize_landmarks = normalize_landmarks
        
        # Get all image files (exclude landmarks and comparison images)
        self.image_files = sorted([f for f in os.listdir(image_dir) 
                                   if f.endswith('.png') and '_landmarks' not in f and '_comparison' not in f])
        
        # Number of landmarks (48 based on the dataset)
        self.num_landmarks = 48
        
    def __len__(self):
        return len(self.image_files)
    
    def __getitem__(self, idx):
        # Load image
        img_name = self.image_files[idx]
        img_path = os.path.join(self.image_dir, img_name)
        image = Image.open(img_path).convert('RGB')
        original_size = image.size  # (width, height)
        
        # Load corresponding label
        label_name = img_name.replace('.png', '.json')
        label_path = os.path.join(self.label_dir, label_name)
        
        with open(label_path, 'r') as f:
            label_data = json.load(f)
        
        landmarks = np.array(label_data['labels'], dtype=np.float32)  # Shape: (48, 2)
        
        # Get the target size from transform (if Resize is present)
        target_size = original_size
        if self.transform:
            for t in self.transform.transforms if hasattr(self.transform, 'transforms') else []:
                if isinstance(t, transforms.Resize):
                    target_size = t.size if isinstance(t.size, tuple) else (t.size, t.size)
                    break
        
        # Normalize landmarks to original image size
        # During training, image will be resized but landmarks stay normalized to original
        # During inference, we multiply by original size to get pixel coordinates
        if self.normalize_landmarks:
            orig_width, orig_height = original_size
            landmarks[:, 0] = landmarks[:, 0] / orig_width
            landmarks[:, 1] = landmarks[:, 1] / orig_height
        
        # Apply transforms (if provided, should include ToTensor)
        if self.transform:
            image = self.transform(image)
        else:
            # Default transform to tensor
            image = transforms.ToTensor()(image)
        
        # Flatten landmarks to (96,) shape: [x1, y1, x2, y2, ..., x48, y48]
        landmarks_flat = landmarks.flatten()
        
        return image, torch.FloatTensor(landmarks_flat)

