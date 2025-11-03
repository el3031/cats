# Cat Facial Landmark Detection

A deep learning model for detecting 48 facial landmarks in cat images using the CatFLW dataset.

## Dataset

The CatFLW dataset contains:
- **2,079 cat images** in PNG format
- **48 facial landmarks** per image (annotated as x, y coordinates)
- Bounding boxes for each cat face

Each label file (JSON) contains:
```json
{
  "labels": [[x1, y1], [x2, y2], ..., [x48, y48]],
  "bounding_boxes": [x_min, y_min, x_max, y_max]
}
```

## Installation

1. Create a virtual environment (recommended):
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Training

Train the model using the default configuration:

```bash
python train.py
```

### Training Configuration

You can modify the training parameters in `train.py`:

- `batch_size`: Batch size (default: 32)
- `num_epochs`: Number of training epochs (default: 100)
- `learning_rate`: Initial learning rate (default: 0.001)
- `val_split`: Validation split ratio (default: 0.2)
- `backbone`: Model backbone architecture (default: 'resnet18')
  - Options: 'resnet18', 'resnet34', 'resnet50'

The training script will:
- Automatically split data into training (80%) and validation (20%) sets
- Save the best model based on validation loss
- Save checkpoints every 10 epochs
- Log training metrics to TensorBoard (view with `tensorboard --logdir logs`)

### Model Architecture

The model uses:
- **Backbone**: ResNet (18/34/50 layers) with pretrained ImageNet weights
- **Head**: Fully connected layers for landmark regression
- **Output**: 96 values (48 landmarks × 2 coordinates)

## Inference

### Predict landmarks for a single image:

```bash
python inference.py --image path/to/cat_image.png
```

This will:
- Predict landmarks for the image
- Save a visualization showing the landmarks overlaid on the image

### Evaluate on multiple images:

```bash
python inference.py --test_dir "CatFLW dataset" --model checkpoints/best_model.pth
```

This will:
- Evaluate the model on test images
- Calculate Normalized Mean Error (NME) for each image
- Generate visualizations for all tested images

### Inference Options

```bash
python inference.py \
  --image path/to/image.png \  # Single image
  --model checkpoints/best_model.pth \  # Model checkpoint
  --backbone resnet18 \  # Model backbone
  --device cuda  # Device (auto, cuda, cpu)
```

## Project Structure

```
cats/
├── CatFLW dataset/
│   ├── images/          # Cat images
│   └── labels/          # JSON label files
├── checkpoints/         # Saved model checkpoints
├── logs/                # TensorBoard logs
├── dataset.py           # Dataset loader
├── model.py             # Model architecture
├── train.py             # Training script
├── inference.py         # Inference script
├── requirements.txt     # Dependencies
└── README.md           # This file
```

## Evaluation Metrics

The model is evaluated using:
- **MSE Loss**: Mean Squared Error between predicted and ground truth landmarks
- **NME (Normalized Mean Error)**: Average landmark error normalized by inter-ocular distance

## Notes

- The model expects RGB images and will resize them to 224×224 during inference
- Landmarks are normalized to [0, 1] range during training for stability
- The model uses data augmentation (horizontal flip, color jitter) during training
- For best results, ensure the input images contain clear, front-facing cat faces

## Example Usage

1. **Train a new model:**
   ```bash
   python train.py
   ```

2. **View training progress:**
   ```bash
   tensorboard --logdir logs
   ```

3. **Test on a single image:**
   ```bash
   python inference.py --image "CatFLW dataset/images/CAT_01_00000183_023.png"
   ```

4. **Evaluate on validation set:**
   ```bash
   python inference.py --test_dir "CatFLW dataset" --model checkpoints/best_model.pth
   ```

