import torch
import torch.nn as nn
import torchvision.models as models


class CatLandmarkModel(nn.Module):
    """CNN-based model for cat facial landmark detection"""
    
    def __init__(self, num_landmarks=48, backbone='resnet18', pretrained=True):
        """
        Args:
            num_landmarks: Number of facial landmarks (48 for CatFLW dataset)
            backbone: Backbone architecture ('resnet18', 'resnet34', 'resnet50')
            pretrained: Whether to use pretrained weights
        """
        super(CatLandmarkModel, self).__init__()
        self.num_landmarks = num_landmarks
        
        # Load backbone
        if backbone == 'resnet18':
            if pretrained:
                backbone_model = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
            else:
                backbone_model = models.resnet18(weights=None)
            num_features = 512
        elif backbone == 'resnet34':
            if pretrained:
                backbone_model = models.resnet34(weights=models.ResNet34_Weights.DEFAULT)
            else:
                backbone_model = models.resnet34(weights=None)
            num_features = 512
        elif backbone == 'resnet50':
            if pretrained:
                backbone_model = models.resnet50(weights=models.ResNet50_Weights.DEFAULT)
            else:
                backbone_model = models.resnet50(weights=None)
            num_features = 2048
        else:
            raise ValueError(f"Unsupported backbone: {backbone}")
        
        # Remove the final fully connected layer
        self.backbone = nn.Sequential(*list(backbone_model.children())[:-1])
        
        # Add global average pooling if not present
        # ResNet already has AdaptiveAvgPool2d, but we need to flatten
        self.avgpool = nn.AdaptiveAvgPool2d((1, 1))
        self.flatten = nn.Flatten()
        
        # Regression head for landmark prediction
        # Output: 2 * num_landmarks (x, y coordinates for each landmark)
        self.fc = nn.Sequential(
            nn.Linear(num_features, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),  # Reduced dropout
            nn.Linear(512, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),  # Reduced dropout
            nn.Linear(256, num_landmarks * 2),
            nn.Sigmoid()  # Constrain outputs to [0, 1] range
        )
        
    def forward(self, x):
        # Extract features
        x = self.backbone(x)
        x = self.avgpool(x)
        x = self.flatten(x)
        
        # Predict landmarks
        landmarks = self.fc(x)
        
        return landmarks

