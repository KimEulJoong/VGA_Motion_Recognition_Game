import cv2
import numpy as np
from skimage.metrics import structural_similarity as ssim

# 1. BMP 파일 읽기
hw_img = cv2.imread("/home/linux/Original.bmp", cv2.IMREAD_GRAYSCALE)
sw_img = cv2.imread("/home/linux/SW_Gray_Sobel.bmp", cv2.IMREAD_GRAYSCALE)

# 2. 이미지 크기 확인
if hw_img.shape != sw_img.shape:
    raise ValueError("HW와 SW 이미지 크기가 다릅니다!")

# 3. PSNR 계산
def calculate_psnr(img1, img2):
    mse = np.mean((img1.astype(np.float64) - img2.astype(np.float64)) ** 2)
    if mse == 0:
        return float('inf')  # 동일 이미지
    PIXEL_MAX = 255.0
    return 20 * np.log10(PIXEL_MAX / np.sqrt(mse))

psnr_value = calculate_psnr(hw_img, sw_img)

# 4. SSIM 계산
ssim_value = ssim(hw_img, sw_img)

# 5. 결과 출력
print(f"PSNR: {psnr_value:.2f} dB")
print(f"SSIM: {ssim_value:.4f}")
