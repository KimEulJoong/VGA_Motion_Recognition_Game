import cv2
import numpy as np

# 1. BMP 24비트 이미지 읽기
src = cv2.imread("Original.bmp", cv2.IMREAD_COLOR)

# 2. 그레이스케일 변환
gray = cv2.cvtColor(src, cv2.COLOR_BGR2GRAY)

gray_12bit = (gray.astype(np.float32) * 16)  # 0~255 -> 0~4080 (≈12bit)
sobel_x = cv2.Sobel(gray_12bit, cv2.CV_32F, 1, 0, ksize=3)
sobel_y = cv2.Sobel(gray_12bit, cv2.CV_32F, 0, 1, ksize=3)
abs_sum = np.abs(sobel_x) + np.abs(sobel_y)
binary_edge = np.where(abs_sum >= 3200, 1, 0).astype(np.uint8)


# 7. 파일 저장 (0/1 -> 0/255 변환)
cv2.imwrite("GrayImage.bmp", gray)
cv2.imwrite("BinaryEdge_12bit_HW.bmp", binary_edge * 255)

# 8. 화면 출력
cv2.imshow("Gray", gray)
cv2.imshow("Binary Edge 12bit HW", binary_edge * 255)
cv2.waitKey(0)
cv2.destroyAllWindows()