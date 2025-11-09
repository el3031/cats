import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, random_split, Subset
from torchvision import transforms
from torch.utils.tensorboard import SummaryWriter
from tqdm import tqdm
import numpy as np

from dataset import CatLandmarkDataset
from model import CatLandmarkModel


def train_epoch(model, dataloader, criterion, optimizer, device):
    """Train for one epoch"""
    model.train()
    running_loss = 0.0
    
    for images, landmarks in tqdm(dataloader, desc='Training'):
        images = images.to(device)
        landmarks = landmarks.to(device)
        
        # Forward pass
        optimizer.zero_grad()
        predictions = model(images)
        
        # Calculate loss
        loss = criterion(predictions, landmarks)
        
        # Backward pass
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item()
    
    return running_loss / len(dataloader)


def validate(model, dataloader, criterion, device):
    """Validate the model"""
    model.eval()
    running_loss = 0.0
    running_nme = 0.0  # Normalized Mean Error
    
    with torch.no_grad():
        for images, landmarks in tqdm(dataloader, desc='Validating'):
            images = images.to(device)
            landmarks = landmarks.to(device)
            
            # Forward pass
            predictions = model(images)
            
            # Calculate loss
            loss = criterion(predictions, landmarks)
            running_loss += loss.item()
            
            # Calculate NME (Normalized Mean Error)
            # Reshape to (batch, num_landmarks, 2)
            pred_landmarks = predictions.view(-1, 48, 2)
            gt_landmarks = landmarks.view(-1, 48, 2)
            
            # Calculate inter-ocular distance as normalization factor
            # Using eye corners (indices 8 and 11 as approximate)
            eye_dist_pred = torch.norm(pred_landmarks[:, 8, :] - pred_landmarks[:, 11, :], dim=1)
            eye_dist_gt = torch.norm(gt_landmarks[:, 8, :] - gt_landmarks[:, 11, :], dim=1)
            eye_dist = torch.clamp(eye_dist_gt, min=1e-5)  # Avoid division by zero
            
            # Calculate mean error per sample
            errors = torch.norm(pred_landmarks - gt_landmarks, dim=2)  # Shape: (batch, 47)
            mean_errors = torch.mean(errors, dim=1)  # Shape: (batch,)
            nme_per_sample = mean_errors / eye_dist
            
            running_nme += nme_per_sample.mean().item()
    
    avg_loss = running_loss / len(dataloader)
    avg_nme = running_nme / len(dataloader)
    
    return avg_loss, avg_nme


def main():
    # Configuration
    config = {
        'data_dir': '/Users/elaine01px2019/Downloads/CatFLW dataset',
        'batch_size': 32,
        'num_epochs': 50,  # Increased for better training
        'learning_rate': 0.0001,  # Lower learning rate for better convergence
        'val_split': 0.2,
        'num_workers': 2,  # Reduced for stability
        'backbone': 'resnet18',
        'pretrained': True,
        'save_dir': 'checkpoints',
        'log_dir': 'logs',
    }
    
    # Set device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")
    
    # Create directories
    os.makedirs(config['save_dir'], exist_ok=True)
    os.makedirs(config['log_dir'], exist_ok=True)
    
    # Data transforms
    train_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ColorJitter(brightness=0.2, contrast=0.2),
        transforms.RandomHorizontalFlip(p=0.5),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    val_transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    
    # Create dataset
    image_dir = os.path.join(config['data_dir'], 'images')
    label_dir = os.path.join(config['data_dir'], 'labels')
    
    # Create full dataset without transform for splitting
    full_dataset = CatLandmarkDataset(image_dir, label_dir, transform=None)
    
    # Split dataset indices
    val_size = int(len(full_dataset) * config['val_split'])
    train_size = len(full_dataset) - val_size
    train_split, val_split = random_split(full_dataset, [train_size, val_size])
    
    # Create separate datasets with appropriate transforms
    train_dataset_full = CatLandmarkDataset(image_dir, label_dir, transform=train_transform)
    val_dataset_full = CatLandmarkDataset(image_dir, label_dir, transform=val_transform)
    
    # Create subsets with the split indices
    train_dataset = Subset(train_dataset_full, train_split.indices)
    val_dataset = Subset(val_dataset_full, val_split.indices)
    
    # Create data loaders
    train_loader = DataLoader(
        train_dataset,
        batch_size=config['batch_size'],
        shuffle=True,
        num_workers=config['num_workers'],
        pin_memory=True if torch.cuda.is_available() else False
    )
    
    val_loader = DataLoader(
        val_dataset,
        batch_size=config['batch_size'],
        shuffle=False,
        num_workers=config['num_workers'],
        pin_memory=True if torch.cuda.is_available() else False
    )
    
    print(f"Train samples: {train_size}, Val samples: {val_size}")
    
    # Create model
    model = CatLandmarkModel(num_landmarks=48, backbone=config['backbone'], pretrained=config['pretrained'])
    model = model.to(device)
    
    # Loss function and optimizer
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=config['learning_rate'])
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='min', factor=0.5, patience=10)
    
    # TensorBoard writer
    writer = SummaryWriter(log_dir=config['log_dir'])
    
    # Training loop
    best_val_loss = float('inf')
    
    for epoch in range(config['num_epochs']):
        print(f"\nEpoch {epoch+1}/{config['num_epochs']}")
        
        # Train
        train_loss = train_epoch(model, train_loader, criterion, optimizer, device)
        
        # Validate
        val_loss, val_nme = validate(model, val_loader, criterion, device)
        
        # Update learning rate
        scheduler.step(val_loss)
        
        # Log to TensorBoard
        writer.add_scalar('Loss/Train', train_loss, epoch)
        writer.add_scalar('Loss/Validation', val_loss, epoch)
        writer.add_scalar('NME/Validation', val_nme, epoch)
        writer.add_scalar('Learning_Rate', optimizer.param_groups[0]['lr'], epoch)
        
        print(f"Train Loss: {train_loss:.6f}, Val Loss: {val_loss:.6f}, Val NME: {val_nme:.6f}")
        
        # Save best model
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            checkpoint = {
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_loss': val_loss,
                'val_nme': val_nme,
            }
            torch.save(checkpoint, os.path.join(config['save_dir'], 'best_model.pth'))
            print(f"Saved best model with val_loss: {val_loss:.6f}")
        
        # Save checkpoint every 10 epochs
        if (epoch + 1) % 10 == 0:
            checkpoint = {
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_loss': val_loss,
                'val_nme': val_nme,
            }
            torch.save(checkpoint, os.path.join(config['save_dir'], f'checkpoint_epoch_{epoch+1}.pth'))
    
    writer.close()
    print("\nTraining completed!")


if __name__ == '__main__':
    main()

