from model import CatLandmarkModel
from inference import predict_landmarks
import numpy as np
import torch
import os

def eyes(landmarks):
    # Calculate vertical vs horizontal distance between eyelids
    left_eye_horizontal_distance = np.linalg.norm(landmarks[9] - landmarks[8])
    left_eye_vertical_distance = np.linalg.norm(landmarks[10] - landmarks[11])
    right_eye_horizontal_distance = np.linalg.norm(landmarks[5] - landmarks[4])
    right_eye_vertical_distance = np.linalg.norm(landmarks[7] - landmarks[6])
    print(f"Left eye horizontal distance: {left_eye_horizontal_distance}, Left eye vertical distance: {left_eye_vertical_distance}")
    print(f"Right eye horizontal distance: {right_eye_horizontal_distance}, Right eye vertical distance: {right_eye_vertical_distance}")
    r_ratio = right_eye_vertical_distance / right_eye_horizontal_distance
    l_ratio = left_eye_vertical_distance / left_eye_horizontal_distance
    if min(l_ratio, r_ratio) > 1: return -1
    elif min(l_ratio, r_ratio) > 0.7: return 0
    elif min(l_ratio, r_ratio) >= 0.5: return 1
    return 2

def ears(landmarks):
    # Calculate angle of ears
    r_ear_a = landmarks[25] - landmarks[26]
    r_ear_b = landmarks[27] - landmarks[26]
    r_cosine_angle = np.dot(r_ear_a, r_ear_b) / (np.linalg.norm(r_ear_a) * np.linalg.norm(r_ear_b))
    r_ear_angle = np.degrees(np.arccos(r_cosine_angle))
    
    l_ear_a = landmarks[28] - landmarks[27]
    l_ear_b = landmarks[26] - landmarks[27]
    l_cosine_angle = np.dot(l_ear_a, l_ear_b) / (np.linalg.norm(l_ear_a) * np.linalg.norm(l_ear_b))
    l_ear_angle = np.degrees(np.arccos(l_cosine_angle))
    print(f"Right ear angle: {r_ear_angle}, Left ear angle: {l_ear_angle}")
    
    ear_base_line = landmarks[31] - landmarks[22]
    l_ear_vertical = landmarks[31] - landmarks[30]
    r_ear_vertical = landmarks[22] - landmarks[23]
    l_vert_cosine_angle = np.dot(ear_base_line, l_ear_vertical) / (np.linalg.norm(ear_base_line) * np.linalg.norm(l_ear_vertical))
    r_vert_cosine_angle = np.dot(ear_base_line, r_ear_vertical) / (np.linalg.norm(ear_base_line) * np.linalg.norm(r_ear_vertical))
    l_vert_angle = np.degrees(np.arccos(l_vert_cosine_angle))
    r_vert_angle = np.degrees(np.arccos(r_vert_cosine_angle))
    print(f"Right ear vertical angle: {r_vert_angle}, Left ear vertical angle: {l_vert_angle}")

    min_ear_ang = min(l_ear_angle, r_ear_angle)
    max_vert_angle = max(l_vert_angle, r_vert_angle)

    if max(l_ear_angle, r_ear_angle) < 115: return -1
    if min_ear_ang > 145 or max_vert_angle < 70: return 2
    if 115 <= min_ear_ang <= 125 or max_vert_angle > 75: return 0
    return 1

def muzzle(landmarks):
    l_muzzle_width = np.linalg.norm(landmarks[44] - landmarks[32])
    r_muzzle_width = np.linalg.norm(landmarks[45] - landmarks[35])
    l_muzzle_height = np.linalg.norm(landmarks[42] - landmarks[21])
    r_muzzle_height = np.linalg.norm(landmarks[43] - landmarks[19])
    l_muzzle_ratio = l_muzzle_width / l_muzzle_height
    r_muzzle_ratio = r_muzzle_width / r_muzzle_height
    print(f"Right muzzle ratio: {r_muzzle_ratio}, Left muzzle ratio: {l_muzzle_ratio}")
    if max(l_muzzle_ratio, r_muzzle_ratio) > 2: return 2
    elif max(l_muzzle_ratio, r_muzzle_ratio) > 1.5: return 1
    elif max(l_muzzle_ratio, r_muzzle_ratio) < 0.8: return -1
    return 0


def calculate_pain_score(image_path, model_path='checkpoints/best_model.pth', num_mc_samples=10):
    """
    Calculate pain score based on landmark positions
    
    Args:
        landmarks: Array of shape (48, 2) with pixel coordinates
    
    Returns:
        eyes: vertical vs horizontal distance between eyelids
        muzzle: 
        ears: angle of ears
    """

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')    
    # Load model
    model = CatLandmarkModel(num_landmarks=48, backbone="resnet18", pretrained=False)
    
    if os.path.exists(model_path):
        checkpoint = torch.load(model_path, map_location=device)
        model.load_state_dict(checkpoint['model_state_dict'])
        print(f"Loaded model from {model_path}")
        if 'val_loss' in checkpoint:
            print(f"Model val_loss: {checkpoint['val_loss']:.6f}")
    else:
        print(f"Warning: Model file {model_path} not found. Using untrained model.")
    
    model = model.to(device)
    model.eval()
    
    # Predict on single image or evaluate on test set
    landmarks, landmarks_norm, plt = predict_landmarks(
        model, image_path, device, save_vis=False
    )
    print(f"\nPredicted {len(landmarks)} landmarks")
    print(f"\nConfidence Scores:")
    print(f"\nLandmark coordinates (pixels):")
    for i, (x, y) in enumerate(landmarks):
        print(f"  Landmark {i}: ({x:.2f}, {y:.2f})")

    eye_score = eyes(landmarks)
    ears_score = ears(landmarks)
    muzzle_score = muzzle(landmarks)
    print(f'eye score: {eye_score}, ears_score: {ears_score}, muzzle_score: {muzzle_score}')

    plt.show()

    if eye_score == -1 or ears_score == -1 or muzzle_score == -1:
        print('ERROR')
    




# calculate_pain_score("/Users/elaine01px2019/Downloads/CatFLW dataset/images/noonoo.jpg")
# calculate_pain_score("/Users/elaine01px2019/Downloads/CatFLW dataset/images/pain.jpg")
calculate_pain_score("/Users/elaine01px2019/Downloads/CatFLW dataset/images/fine.jpg")

# calculate_pain_score("/Users/elaine01px2019/Downloads/CatFLW dataset/images/CAT_01_00000142_006.png")