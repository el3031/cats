import os
import json
import torch
import numpy as np
from PIL import Image
from torchvision import transforms
import matplotlib.pyplot as plt
from collections import defaultdict
import statistics

from model import CatLandmarkModel
from inference import predict_landmarks


def analyze_validation_results(test_data_dir, model_path, num_samples=50):
    """Comprehensive analysis of model validation results"""
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}\n")
    
    # Load model
    model = CatLandmarkModel(num_landmarks=48, backbone='resnet18', pretrained=False)
    checkpoint = torch.load(model_path, map_location=device)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.to(device)
    model.eval()
    
    image_dir = os.path.join(test_data_dir, 'images')
    label_dir = os.path.join(test_data_dir, 'labels')
    
    # Get image files
    image_files = sorted([f for f in os.listdir(image_dir) 
                         if f.endswith('.png') and not f.endswith('_landmarks.png') and not f.endswith('_comparison.png')])[:num_samples]
    
    results = []
    nme_values = []
    
    print(f"Analyzing {len(image_files)} images...\n")
    
    for img_file in image_files:
        img_path = os.path.join(image_dir, img_file)
        label_path = os.path.join(label_dir, img_file.replace('.png', '.json'))
        
        # Load ground truth
        with open(label_path, 'r') as f:
            gt_data = json.load(f)
        gt_landmarks = np.array(gt_data['labels'], dtype=np.float32)
        
        # Predict
        pred_landmarks, _ = predict_landmarks(model, img_path, device, save_vis=False)
        
        # Load image for size
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
        
        # Calculate errors per landmark
        errors = np.linalg.norm(pred_normalized - gt_normalized, axis=1)
        mean_error = np.mean(errors)
        nme = mean_error / eye_dist
        
        # Calculate per-landmark errors
        landmark_errors = errors / eye_dist
        
        results.append({
            'image': img_file,
            'nme': nme,
            'mean_error': mean_error,
            'max_landmark_error': np.max(landmark_errors),
            'min_landmark_error': np.min(landmark_errors),
            'std_error': np.std(landmark_errors),
            'image_size': (img_width, img_height),
            'errors': landmark_errors
        })
        
        nme_values.append(nme)
    
    # Sort by NME
    results_sorted = sorted(results, key=lambda x: x['nme'])
    
    # Print statistics
    print("=" * 80)
    print("VALIDATION STATISTICS")
    print("=" * 80)
    print(f"Total images analyzed: {len(results)}")
    print(f"\nNME Statistics:")
    print(f"  Mean NME: {np.mean(nme_values):.6f}")
    print(f"  Median NME: {np.median(nme_values):.6f}")
    print(f"  Std NME: {np.std(nme_values):.6f}")
    print(f"  Min NME: {np.min(nme_values):.6f}")
    print(f"  Max NME: {np.max(nme_values):.6f}")
    print(f"  25th percentile: {np.percentile(nme_values, 25):.6f}")
    print(f"  75th percentile: {np.percentile(nme_values, 75):.6f}")
    
    # Categorize results
    excellent = [r for r in results if r['nme'] < 0.5]
    good = [r for r in results if 0.5 <= r['nme'] < 1.0]
    fair = [r for r in results if 1.0 <= r['nme'] < 2.0]
    poor = [r for r in results if r['nme'] >= 2.0]
    
    print(f"\nPerformance Categories:")
    print(f"  Excellent (NME < 0.5): {len(excellent)} images ({100*len(excellent)/len(results):.1f}%)")
    print(f"  Good (0.5 ≤ NME < 1.0): {len(good)} images ({100*len(good)/len(results):.1f}%)")
    print(f"  Fair (1.0 ≤ NME < 2.0): {len(fair)} images ({100*len(fair)/len(results):.1f}%)")
    print(f"  Poor (NME ≥ 2.0): {len(poor)} images ({100*len(poor)/len(results):.1f}%)")
    
    # Best and worst images
    print(f"\nTop 5 Best Performing Images:")
    for i, result in enumerate(results_sorted[:5], 1):
        print(f"  {i}. {result['image']}: NME = {result['nme']:.6f}")
    
    print(f"\nTop 5 Worst Performing Images:")
    for i, result in enumerate(results_sorted[-5:][::-1], 1):
        print(f"  {i}. {result['image']}: NME = {result['nme']:.6f}")
    
    # Analyze outliers
    q1 = np.percentile(nme_values, 25)
    q3 = np.percentile(nme_values, 75)
    iqr = q3 - q1
    outlier_threshold = q3 + 1.5 * iqr
    
    outliers = [r for r in results if r['nme'] > outlier_threshold]
    print(f"\nOutliers (NME > {outlier_threshold:.3f}): {len(outliers)} images")
    for outlier in sorted(outliers, key=lambda x: x['nme'], reverse=True):
        print(f"  {outlier['image']}: NME = {outlier['nme']:.6f}")
    
    # Analyze landmark-specific errors
    print(f"\nLandmark Error Analysis:")
    all_landmark_errors = np.array([r['errors'] for r in results])
    landmark_means = np.mean(all_landmark_errors, axis=0)
    landmark_stds = np.std(all_landmark_errors, axis=0)
    
    worst_landmarks = np.argsort(landmark_means)[-5:][::-1]
    best_landmarks = np.argsort(landmark_means)[:5]
    
    print(f"  Worst performing landmarks (highest mean error):")
    for idx in worst_landmarks:
        print(f"    Landmark {idx}: mean error = {landmark_means[idx]:.6f} ± {landmark_stds[idx]:.6f}")
    
    print(f"  Best performing landmarks (lowest mean error):")
    for idx in best_landmarks:
        print(f"    Landmark {idx}: mean error = {landmark_means[idx]:.6f} ± {landmark_stds[idx]:.6f}")
    
    # Create visualization
    create_analysis_plots(results, nme_values, test_data_dir)
    
    return results


def create_analysis_plots(results, nme_values, output_dir):
    """Create visualization plots for analysis"""
    
    # 1. NME distribution histogram
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    
    # Histogram
    axes[0, 0].hist(nme_values, bins=20, edgecolor='black', alpha=0.7)
    axes[0, 0].axvline(np.mean(nme_values), color='r', linestyle='--', label=f'Mean: {np.mean(nme_values):.3f}')
    axes[0, 0].axvline(np.median(nme_values), color='g', linestyle='--', label=f'Median: {np.median(nme_values):.3f}')
    axes[0, 0].set_xlabel('NME')
    axes[0, 0].set_ylabel('Frequency')
    axes[0, 0].set_title('NME Distribution')
    axes[0, 0].legend()
    axes[0, 0].grid(True, alpha=0.3)
    
    # Box plot
    axes[0, 1].boxplot(nme_values, vert=True)
    axes[0, 1].set_ylabel('NME')
    axes[0, 1].set_title('NME Box Plot')
    axes[0, 1].grid(True, alpha=0.3)
    
    # Sorted NME values
    sorted_nme = sorted(nme_values)
    axes[1, 0].plot(range(len(sorted_nme)), sorted_nme, marker='o', markersize=3)
    axes[1, 0].axhline(np.mean(nme_values), color='r', linestyle='--', label=f'Mean: {np.mean(nme_values):.3f}')
    axes[1, 0].set_xlabel('Image Index (sorted)')
    axes[1, 0].set_ylabel('NME')
    axes[1, 0].set_title('Sorted NME Values')
    axes[1, 0].legend()
    axes[1, 0].grid(True, alpha=0.3)
    
    # Performance categories pie chart
    excellent = len([r for r in results if r['nme'] < 0.5])
    good = len([r for r in results if 0.5 <= r['nme'] < 1.0])
    fair = len([r for r in results if 1.0 <= r['nme'] < 2.0])
    poor = len([r for r in results if r['nme'] >= 2.0])
    
    categories = ['Excellent\n(NME < 0.5)', 'Good\n(0.5 ≤ NME < 1.0)', 
                  'Fair\n(1.0 ≤ NME < 2.0)', 'Poor\n(NME ≥ 2.0)']
    sizes = [excellent, good, fair, poor]
    colors = ['#2ecc71', '#3498db', '#f39c12', '#e74c3c']
    
    axes[1, 1].pie(sizes, labels=categories, colors=colors, autopct='%1.1f%%', startangle=90)
    axes[1, 1].set_title('Performance Distribution')
    
    plt.tight_layout()
    plot_path = os.path.join(output_dir, 'validation_analysis.png')
    plt.savefig(plot_path, dpi=150, bbox_inches='tight')
    print(f"\nSaved analysis plots to: {plot_path}")
    plt.close()
    
    # Create comparison for worst cases
    worst_results = sorted(results, key=lambda x: x['nme'], reverse=True)[:3]
    create_outlier_comparisons(worst_results, output_dir)


def create_outlier_comparisons(worst_results, output_dir):
    """Create comparison visualizations for worst performing images"""
    from compare_predictions import compare_prediction_gt
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    model = CatLandmarkModel(num_landmarks=48, backbone='resnet18', pretrained=False)
    checkpoint = torch.load('checkpoints/best_model.pth', map_location=device)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.to(device)
    model.eval()
    
    image_dir = os.path.join(output_dir, 'images')
    label_dir = os.path.join(output_dir, 'labels')
    
    print(f"\nCreating comparison visualizations for worst cases...")
    for result in worst_results:
        img_file = result['image']
        img_path = os.path.join(image_dir, img_file)
        label_path = os.path.join(label_dir, img_file.replace('.png', '.json'))
        compare_prediction_gt(img_path, label_path, model, device)


if __name__ == '__main__':
    import sys
    
    test_dir = "/Users/elaine01px2019/Downloads/CatFLW dataset"
    model_path = "checkpoints/best_model.pth"
    
    if len(sys.argv) > 1:
        test_dir = sys.argv[1]
    if len(sys.argv) > 2:
        model_path = sys.argv[2]
    
    results = analyze_validation_results(test_dir, model_path, num_samples=50)
    
    print("\n" + "=" * 80)
    print("Analysis complete!")
    print("=" * 80)

