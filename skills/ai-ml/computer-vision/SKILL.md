---
name: computer-vision
description: >
  Computer vision tasks: image classification, object detection, OCR, and manga/comic image processing. Triggers on: computer vision, PIL, Pillow, OpenCV, cv2, OCR, tesseract, object detection, image classification, YOLO, manga processing.
---

# Computer Vision

## When to Use
Use this skill for image loading/manipulation, object detection, OCR text extraction, image classification, manga panel/bubble processing, or building batch image pipelines. Covers PIL/Pillow, OpenCV, Tesseract, EasyOCR, YOLO, and Claude Vision API.

---

## Core Rules
- PIL/Pillow for image I/O and basic transforms; OpenCV for pixel-level operations and contour detection.
- For OCR quality: Claude Vision API > EasyOCR > Tesseract (especially for manga/stylized fonts).
- Always convert PIL images to numpy arrays for OpenCV (`np.array(img)`), and back with `Image.fromarray(arr)`.
- BGR vs RGB: OpenCV loads as BGR; PIL/most APIs expect RGB. Always convert: `cv2.cvtColor(img, cv2.COLOR_BGR2RGB)`.
- Batch pipelines: use `pathlib.Path` + generator patterns for memory efficiency on large sets.

---

## PIL / Pillow Basics

```python
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw
import numpy as np

# Load, inspect, save
img = Image.open("photo.jpg")
print(img.size, img.mode)   # (width, height), 'RGB' / 'RGBA' / 'L'
img.save("output.png")

# Resize
img_resized = img.resize((800, 600))
img_thumb = img.copy(); img_thumb.thumbnail((256, 256))  # preserves aspect

# Convert modes
gray = img.convert("L")       # grayscale
rgba = img.convert("RGBA")    # add alpha channel

# Crop (left, upper, right, lower)
cropped = img.crop((100, 100, 500, 400))

# Rotate / flip
rotated = img.rotate(90, expand=True)
flipped = img.transpose(Image.FLIP_LEFT_RIGHT)

# Filters
blurred = img.filter(ImageFilter.GaussianBlur(radius=3))
sharp = img.filter(ImageFilter.SHARPEN)

# Enhance
enhancer = ImageEnhance.Contrast(img)
img_high_contrast = enhancer.enhance(2.0)

# Draw on image
draw = ImageDraw.Draw(img)
draw.rectangle([10, 10, 200, 200], outline="red", width=3)
draw.text((20, 20), "Label", fill="white")

# PIL <-> numpy
arr = np.array(img)          # PIL to numpy (RGB)
img_back = Image.fromarray(arr)  # numpy to PIL
```

---

## OpenCV Fundamentals

```python
import cv2
import numpy as np

# Read / write
img = cv2.imread("photo.jpg")          # BGR format
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)  # fix to RGB
cv2.imwrite("output.jpg", img)

# Resize
img_resized = cv2.resize(img, (800, 600))
img_half = cv2.resize(img, None, fx=0.5, fy=0.5)

# Grayscale + threshold
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
_, binary = cv2.threshold(gray, 128, 255, cv2.THRESH_BINARY)
adaptive = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                  cv2.THRESH_BINARY, 11, 2)

# Blur
blurred = cv2.GaussianBlur(img, (5, 5), 0)
median = cv2.medianBlur(img, 5)

# Edge detection
edges = cv2.Canny(gray, 50, 150)

# Contour detection (e.g. panel borders)
contours, hierarchy = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
for cnt in contours:
    area = cv2.contourArea(cnt)
    if area > 5000:
        x, y, w, h = cv2.boundingRect(cnt)
        cv2.rectangle(img, (x, y), (x+w, y+h), (0, 255, 0), 2)

# Morphological ops (useful for manga cleanup)
kernel = np.ones((3, 3), np.uint8)
dilated = cv2.dilate(binary, kernel, iterations=1)
eroded = cv2.erode(binary, kernel, iterations=1)
cleaned = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)

# Display (non-blocking for scripts)
cv2.imshow("Result", img)
cv2.waitKey(0)
cv2.destroyAllWindows()
```

---

## OCR with Tesseract (pytesseract)

```bash
# Install
pip install pytesseract pillow
brew install tesseract               # macOS
# sudo apt install tesseract-ocr    # Linux
```

```python
import pytesseract
from PIL import Image
import cv2
import numpy as np

# Basic OCR
img = Image.open("document.png")
text = pytesseract.image_to_string(img)
print(text)

# With preprocessing for better accuracy
def preprocess_for_ocr(pil_img):
    gray = pil_img.convert("L")
    arr = np.array(gray)
    # Upscale if small
    if arr.shape[0] < 600:
        arr = cv2.resize(arr, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
    # Threshold
    _, arr = cv2.threshold(arr, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return Image.fromarray(arr)

img_processed = preprocess_for_ocr(img)
text = pytesseract.image_to_string(img_processed, config='--psm 6')

# PSM modes:
# 3 = fully automatic (default)
# 6 = single uniform block of text
# 7 = single text line
# 11 = sparse text (no order)
# 13 = raw line

# Get bounding boxes
data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
for i, word in enumerate(data['text']):
    if word.strip():
        x, y, w, h = data['left'][i], data['top'][i], data['width'][i], data['height'][i]
        conf = data['conf'][i]
        print(f"'{word}' @ ({x},{y}) conf={conf}")

# Japanese/Korean/Chinese (requires language pack)
text_jp = pytesseract.image_to_string(img, lang='jpn')
# brew install tesseract-lang  (macOS for all lang packs)
```

---

## OCR with EasyOCR (better multilingual, no Tesseract needed)

```bash
pip install easyocr
```

```python
import easyocr
from PIL import Image
import numpy as np

# Initialize (downloads model on first run)
reader = easyocr.Reader(['en'])                    # English
reader_jp = easyocr.Reader(['ja', 'en'])           # Japanese + English
reader_ko = easyocr.Reader(['ko', 'en'])           # Korean

# Run OCR
img_path = "document.png"
results = reader.readtext(img_path)

# Results: list of ([bbox], text, confidence)
for (bbox, text, conf) in results:
    print(f"{text!r} (conf={conf:.2f}) at {bbox}")

# Extract just text
texts = [text for (_, text, conf) in results if conf > 0.5]

# On numpy array
img_arr = np.array(Image.open("document.png"))
results = reader.readtext(img_arr)

# Paragraph mode (merge nearby text)
results = reader.readtext(img_path, paragraph=True)
```

---

## Claude Vision API for OCR (highest quality)

```python
import anthropic
import base64
from pathlib import Path

client = anthropic.Anthropic()

def ocr_with_claude(image_path: str, prompt: str = None) -> str:
    """Use Claude Vision for OCR — best quality, especially for manga/stylized text."""
    img_data = Path(image_path).read_bytes()
    img_b64 = base64.standard_b64encode(img_data).decode("utf-8")

    # Detect media type
    suffix = Path(image_path).suffix.lower()
    media_map = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
                 ".png": "image/png", ".webp": "image/webp", ".gif": "image/gif"}
    media_type = media_map.get(suffix, "image/jpeg")

    if prompt is None:
        prompt = "Extract all text from this image exactly as written. Preserve formatting and line breaks."

    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=2048,
        messages=[{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": media_type, "data": img_b64}},
                {"type": "text", "text": prompt}
            ]
        }]
    )
    return message.content[0].text

# For manga speech bubbles
def ocr_manga_panel(image_path: str) -> dict:
    return ocr_with_claude(
        image_path,
        prompt="This is a manga panel. Extract all dialogue text from speech bubbles and thought bubbles. "
               "Return as JSON: {\"bubbles\": [{\"text\": \"...\", \"type\": \"speech|thought|narration\"}]}"
    )
```

---

## YOLO Object Detection

```bash
pip install ultralytics
```

```python
from ultralytics import YOLO
from PIL import Image
import cv2

# Load pre-trained model
model = YOLO("yolov8n.pt")   # nano: fast; yolov8s/m/l/x for more accuracy
# Downloads automatically on first run

# Detect on image
results = model("photo.jpg")

# Process results
for result in results:
    boxes = result.boxes
    for box in boxes:
        cls_id = int(box.cls[0])
        conf = float(box.conf[0])
        xyxy = box.xyxy[0].tolist()   # [x1, y1, x2, y2]
        label = model.names[cls_id]
        print(f"{label}: {conf:.2f} @ {xyxy}")

    # Save annotated image
    result.save("annotated.jpg")

# Batch detection
results = model(["img1.jpg", "img2.jpg", "img3.jpg"])

# Run on video
results = model("video.mp4", stream=True)
for result in results:
    frame = result.orig_img  # numpy BGR frame
    # process...

# Custom confidence threshold
results = model("photo.jpg", conf=0.4)

# Specific classes only (0=person, 2=car in COCO)
results = model("photo.jpg", classes=[0, 2])
```

---

## Manga-Specific: Panel Detection

```python
import cv2
import numpy as np
from PIL import Image
from pathlib import Path

def detect_manga_panels(image_path: str) -> list[dict]:
    """Detect individual panels in a manga page using contour detection."""
    img = cv2.imread(image_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Manga pages usually have black panel borders on white background
    # Invert if background is dark
    mean_val = np.mean(gray)
    if mean_val < 128:
        gray = cv2.bitwise_not(gray)

    # Threshold to get panel borders
    _, binary = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)

    # Close gaps in borders
    kernel = np.ones((3, 3), np.uint8)
    closed = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel, iterations=2)

    # Find contours
    contours, _ = cv2.findContours(closed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    h, w = img.shape[:2]
    min_area = (h * w) * 0.02   # ignore tiny regions

    panels = []
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < min_area:
            continue
        x, y, pw, ph = cv2.boundingRect(cnt)
        panels.append({"x": x, "y": y, "w": pw, "h": ph, "area": area})

    # Sort top-to-bottom, left-to-right
    panels.sort(key=lambda p: (p["y"] // 100, p["x"]))
    return panels

def extract_panels(image_path: str, output_dir: str) -> list[str]:
    """Extract each detected panel as a separate image."""
    from pathlib import Path
    img = Image.open(image_path)
    panels = detect_manga_panels(image_path)
    out = Path(output_dir)
    out.mkdir(exist_ok=True)
    saved = []
    for i, p in enumerate(panels):
        cropped = img.crop((p["x"], p["y"], p["x"]+p["w"], p["y"]+p["h"]))
        path = str(out / f"panel_{i:03d}.png")
        cropped.save(path)
        saved.append(path)
    return saved
```

---

## Manga-Specific: Speech Bubble Detection

```python
import cv2
import numpy as np

def detect_speech_bubbles(image_path: str) -> list[dict]:
    """Detect white speech bubbles using contour + circularity heuristics."""
    img = cv2.imread(image_path)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Bubbles are typically white with dark outlines
    _, binary = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY)

    kernel = np.ones((2, 2), np.uint8)
    cleaned = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel, iterations=1)

    contours, _ = cv2.findContours(cleaned, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    bubbles = []
    h, w = img.shape[:2]
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area < 500 or area > (h * w * 0.4):
            continue

        # Circularity check: 4π·area / perimeter² (1.0 = perfect circle)
        perimeter = cv2.arcLength(cnt, True)
        if perimeter == 0:
            continue
        circularity = (4 * np.pi * area) / (perimeter ** 2)

        # Bubbles are roundish (not panel-shaped rectangles)
        if circularity > 0.3:
            x, y, bw, bh = cv2.boundingRect(cnt)
            bubbles.append({
                "x": x, "y": y, "w": bw, "h": bh,
                "circularity": circularity, "area": area
            })

    return sorted(bubbles, key=lambda b: (b["y"], b["x"]))
```

---

## Batch Image Processing Pipeline

```python
from pathlib import Path
from PIL import Image
import concurrent.futures

def process_image(path: Path, output_dir: Path) -> dict:
    """Process a single image — customize as needed."""
    try:
        img = Image.open(path).convert("RGB")
        # Example: resize + convert
        img.thumbnail((1024, 1024))
        out_path = output_dir / (path.stem + "_processed.jpg")
        img.save(out_path, "JPEG", quality=85, optimize=True)
        return {"file": path.name, "status": "ok", "out": str(out_path)}
    except Exception as e:
        return {"file": path.name, "status": "error", "error": str(e)}

def batch_process(input_dir: str, output_dir: str, workers: int = 4):
    """Batch process all images in a directory."""
    in_path = Path(input_dir)
    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)

    image_files = list(in_path.glob("**/*.{jpg,jpeg,png,webp}"))
    # Flatten globs for multiple extensions
    exts = ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG"]
    image_files = [f for ext in exts for f in in_path.glob(ext)]

    print(f"Processing {len(image_files)} images...")
    results = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {executor.submit(process_image, f, out_path): f for f in image_files}
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            status = result["status"]
            print(f"[{status}] {result['file']}")

    errors = [r for r in results if r["status"] == "error"]
    print(f"Done: {len(results) - len(errors)} OK, {len(errors)} errors")
    return results
```

---

## Image Classification (torchvision / timm)

```bash
pip install torch torchvision timm pillow
```

```python
import torch
import timm
from PIL import Image
from torchvision import transforms

# Load pretrained model
model = timm.create_model("efficientnet_b0", pretrained=True)
model.eval()

# Standard ImageNet preprocessing
transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

def classify(image_path: str, top_k: int = 5) -> list[tuple[str, float]]:
    img = Image.open(image_path).convert("RGB")
    tensor = transform(img).unsqueeze(0)  # add batch dim

    with torch.no_grad():
        logits = model(tensor)
        probs = torch.softmax(logits, dim=1)[0]
        top = torch.topk(probs, top_k)

    # Load ImageNet labels
    import urllib.request, json
    url = "https://storage.googleapis.com/download.tensorflow.org/data/imagenet_class_index.json"
    with urllib.request.urlopen(url) as r:
        class_idx = json.loads(r.read().decode())
    labels = {int(k): v[1] for k, v in class_idx.items()}

    return [(labels[idx.item()], prob.item()) for idx, prob in zip(top.indices, top.values)]

results = classify("photo.jpg")
for label, prob in results:
    print(f"{label}: {prob:.3f}")
```

---

## Quick Reference

| Task | Best Tool | Notes |
|------|-----------|-------|
| Basic image I/O | PIL/Pillow | Easiest API |
| Contour/edge detection | OpenCV | `findContours`, `Canny` |
| OCR — printed text | Tesseract / EasyOCR | Preprocess first |
| OCR — manga/stylized | Claude Vision API | Best accuracy |
| Object detection | YOLOv8 (ultralytics) | Fast, pretrained |
| Classification | timm + EfficientNet | Wide model zoo |
| Manga panel detection | OpenCV contours | Custom thresholds |
| Batch processing | ThreadPoolExecutor | I/O bound → threads |
