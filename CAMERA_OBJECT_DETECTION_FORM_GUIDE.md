## Flutter Camera Object Detection Form (Documentation)

This guide explains **what to set up** and **what to use** to build a Flutter “form” screen that:

- Lets a user **take a photo** (camera) or **choose an image** (gallery)
- Runs **automatic object detection** on the captured/selected image
- Displays:
  - **Detected bounding rectangle**
  - **Pixel width/height**
  - **Corner coordinates**
  - **Real‑world size** (cm/mm) *only when calibration/reference is available*
- Provides a **manual adjustment fallback** so the feature always works

No code is included—this is a setup + architecture + step‑by‑step checklist.

---

### 0) Important reality check (so you don’t get stuck)

- **“Perfect detection” is not guaranteed** with classical image processing for all lighting, reflections, and angles.
- The best practical approach in production is:
  - **Fast CV (contours) first** (cheap + quick)
  - **ML fallback** (more robust on hard scenes)
  - **Manual adjustment fallback** (guarantees the user can complete the task)
- **Real‑world size (cm/mm) cannot be accurate without calibration or a known‑size reference** in the same photo (or depth/AR).

---

### 1) Choose your detection approach (what should I use?)

Pick one of these options based on your object type and reliability needs:

#### Option A — Classical (Contour/Rectangle detection) (fastest)
Use when:
- The target object is mostly **rectangular** (phone, card, paper, box)
- You want **<300ms** detection on-device

Recommended tools:
- **`image`** package: basic preprocessing (grayscale, blur, Sobel/threshold, morphology)
- **`opencv_dart`** (recommended) or **`opencv_4`** (older): if you want real OpenCV functions like Canny, findContours, approxPolyDP, minAreaRect

Pros:
- Very fast, low CPU, no model files
Cons:
- Can fail with heavy reflections, clutter, weak edges, extreme angles

#### Option B — ML Object Detection / Segmentation (most robust)
Use when:
- You need higher reliability across many conditions
- The object isn’t always a clean rectangle

Recommended tools:
- **`tflite_flutter`**: run TFLite models on device
- (Optional) A segmentation model (mask output) is often better than box-only detection for accuracy

Pros:
- Handles reflections/complex backgrounds better
Cons:
- Model management + tuning + potential >300ms on low-end devices unless optimized

#### Option C — Hybrid (Recommended for production)
Pipeline:
- Try **contour rectangle detection**
- If confidence/quality is low → run **ML fallback**
- If still low → show **manual corner editor**

This is the most reliable user experience.

---

### 2) Set up your Flutter project (camera + image input)

Your app needs these building blocks:

- **Camera capture**
  - Use `camera` for live preview + taking a photo.
- **Gallery / file input**
  - Use `image_picker` for selecting an existing image.
- **State management**
  - Use `provider` (or Riverpod/BLoC) to store:
    - captured image bytes/path
    - image width/height
    - detection result (corners/box)
    - measurement/calibration info
- **Image processing**
  - `image` and/or OpenCV bindings
- **Performance**
  - Run detection in an **isolate** (background thread) after capture/selection

Platform setup checklist:
- **Android**
  - Add camera permission in the Android manifest
  - Ensure minSdk/targetSdk compatible with your camera plugin version
- **iOS**
  - Add camera + photo library usage descriptions in Info.plist

---

### 3) Design the “Form” screen UX (recommended layout)

Build one screen that looks like a form, with these sections:

#### A) Image input section
- Buttons:
  - **Take photo**
  - **Choose from gallery**
- A preview area that shows the chosen image

#### B) Detection result section (auto)
- When an image is selected:
  - Show “Detecting…” (progress)
  - Then show:
    - **Image size** (width × height px)
    - **Detected object size** (widthPx, heightPx)
    - **Corner points** (topLeft, topRight, bottomRight, bottomLeft)
    - **Converted size** (cm/mm) if calibration exists

#### C) Manual adjust section (fallback + improvement)
- Always allow “Adjust” even if detection succeeds
- Manual editor should support:
  - Dragging corners or edges
  - Showing updated px sizes live

#### D) Submit section
- “Confirm” button saves the selected object bounds + measurements
- On submit, store the final measurement in your app state / backend

---

### 4) When to run detection (performance requirement)

To keep the app fast and stable:

- Run detection **only after**:
  - a photo is taken, or
  - an image is selected
- Do **not** run detection on every camera frame (too slow / battery heavy).
- Downscale the image for detection (e.g., max side 400–800px), then map coordinates back.
- Use an **isolate** if detection can exceed ~100–150ms on your target devices.

Target: **<300ms total** for most images.

---

### 5) Classical rectangle detection pipeline (the “OpenCV-style” steps)

If your goal is “detect largest rectangle,” this is the standard pipeline:

1. **Convert to grayscale**
2. **Gaussian blur** (5×5 kernel)
3. **Edge detection**
   - Canny is ideal; if not available, use Sobel magnitude + threshold.
4. **Dilate edges**
   - Connect broken edges so contours become complete
5. **Find contours**
6. **Filter contours**
   - Area > **5000 px** (scale this threshold if you downsample)
   - Approximate polygon has **4 corners**
   - Optional: aspect ratio constraints (avoid crazy thin shapes)
7. **Choose largest valid rectangle**
8. **Compute geometry**
   - Bounding rectangle (or rotated rectangle for angled photos)
   - WidthPx / HeightPx
   - Corner coordinates
9. **Draw overlay**
10. **Send result to the overlay/editor system**

For angled photos:
- Prefer **rotated rectangle** (`minAreaRect`) and return **4 corner points**
- (Optional) Apply perspective correction (homography) if you need measurements in a rectified plane

---

### 6) Showing the overlay (bounding box + corner points)

Use a dedicated overlay layer above the image:

- Display:
  - Rectangle outline (green)
  - Crosshair lines (blue) if you want
  - Corner handles when editing
- Keep all overlay coordinates in **image pixel space**
  - Convert to screen space using a single scale factor based on how the image is fitted (contain/cover).

This prevents “wrong box position” bugs.

---

### 7) Measuring “size” correctly (pixels vs cm/mm)

You can always show:
- **Pixel width (px)**
- **Pixel height (px)**

To show **cm/mm**, you must have one of these:

#### A) Known-size reference object in the same image (recommended)
Examples:
- Credit card
- A4 sheet
- A ruler segment (user selects 10cm, etc.)

Process:
- Detect the reference rectangle (or let user mark its corners)
- Compute pixels-per-mm (or a perspective-aware scale)
- Convert object px → mm/cm

#### B) Fixed calibration (works only with controlled setup)
Examples:
- Same device, fixed camera height, fixed zoom, fixed surface

Store:
- pixels-per-mm value for that setup

#### C) Depth/AR approach (most accurate, most complex)
Examples:
- ARCore / ARKit plane detection + distance

This is best if you must support many angles/distances without requiring a reference object.

---

### 8) Confidence + fallback rules (so the UX is reliable)

Define “detection success” rules. Example checks:

- Rectangle area ratio is not too small (object isn’t tiny) and not too huge (whole image)
- Polygon has 4 corners (or rotated rectangle confidence is high)
- Edges are strong (enough edge pixels)

If confidence is low:
- Immediately show manual editor

Even if confidence is high:
- Still allow manual adjustment (users expect it)

---

### 9) Testing checklist (this is where “perfect” gets closer)

Collect a small dataset of real images from your target users:

- Dark objects on light table
- Reflective screens
- Bright sunlight
- Low light
- Angled shots
- Busy background

For each image:
- Check bounding box accuracy
- Record failure cases
- Tune thresholds / add preprocessing (contrast enhancement, adaptive thresholds)

If many failures remain:
- Add ML fallback (segmentation often works best)

---

### 10) Recommended “what to implement” list (deliverables)

To keep your code maintainable, organize like this:

- **`ObjectDetectionService`**
  - Input: image bytes
  - Output: detection result (box + corners + width/height px + confidence)
- **`DetectionResult` model**
  - corners
  - widthPx / heightPx
  - imageWidth / imageHeight
  - confidence + method (auto/ML/manual)
- **Form screen**
  - image input
  - “detect” state
  - result display
  - manual adjust button
- **Manual editor widget**
  - draggable corners/edges
  - returns corrected corners/bounds
- **Overlay painter**
  - draws detection result consistently

---

### 11) Quick “Which package should I pick?” summary

- If your object is mostly a rectangle and you want speed:
  - **`image`** (+ optional **`opencv_dart`**) for contour detection
- If you need robust detection across many conditions:
  - **`tflite_flutter`** with a detection/segmentation model
- For best user experience:
  - **Hybrid**: contour first → ML fallback → manual fallback

---

### 12) Where this fits in your current project

Your current app already has the needed screens and architecture:

- Camera capture screen (photo acquisition)
- Detection screen (auto detection + manual adjustment)
- Review screen (display overlay + sizes)
- Measurement service (detection pipeline)

If you want the “form” style UI, the main work is:
- Build a single form page that wraps those actions (take/select image → detect → show results → confirm).

