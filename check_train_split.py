import os
import torch
from torch.utils.data import Dataset, random_split
from dataset import CatLandmarkDataset

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

print(f"Total dataset size: {len(full_dataset)}")
print(f"Train samples: {train_size}, Val samples: {val_size}\n")

# Get the actual image filenames for train and validation sets
train_indices = train_split.indices
val_indices = val_split_indices.indices

# Get all image files (sorted)
all_image_files = sorted([f for f in os.listdir(image_dir) 
                         if f.endswith('.png') and '_landmarks' not in f and '_comparison' not in f])

# Get filenames for train and val sets
train_files = [all_image_files[i] for i in train_indices]
val_files = [all_image_files[i] for i in val_indices]

print(f"Train set: {len(train_files)} images")
print(f"Validation set: {len(val_files)} images\n")

# Check which images were used in the 50-image test
test_files = all_image_files[:50]

print("=" * 80)
print("CHECKING WHICH SET THE 50 TEST IMAGES BELONG TO")
print("=" * 80)

train_count = 0
val_count = 0
unknown_count = 0

for img_file in test_files:
    if img_file in train_files:
        train_count += 1
    elif img_file in val_files:
        val_count += 1
    else:
        unknown_count += 1

print(f"\nOut of 50 test images:")
print(f"  In TRAINING set: {train_count} images ({100*train_count/50:.1f}%)")
print(f"  In VALIDATION set: {val_count} images ({100*val_count/50:.1f}%)")
print(f"  Unknown: {unknown_count} images\n")

if train_count > 0:
    print("⚠️  WARNING: Some test images were in the training set!")
    print("   This means the model has seen these images during training.")
    print("   Performance metrics may be inflated.\n")
    print("Images in training set:")
    for img_file in test_files:
        if img_file in train_files:
            print(f"  - {img_file}")
else:
    print("✓ All test images were in the validation set (not seen during training)")

print("\n" + "=" * 80)
print("First 10 images in each set:")
print("=" * 80)
print(f"\nFirst 10 TRAIN images:")
for img in train_files[:10]:
    print(f"  {img}")

print(f"\nFirst 10 VALIDATION images:")
for img in val_files[:10]:
    print(f"  {img}")

print(f"\nFirst 10 TEST images (first 10 of the 50 we tested):")
for img in test_files[:10]:
    in_train = "✓ TRAIN" if img in train_files else ""
    in_val = "✓ VAL" if img in val_files else ""
    print(f"  {img} {in_train} {in_val}")

