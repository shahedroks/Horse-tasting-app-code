## Camera Object Detection Integration Guide

This document explains, step by step, how the camera object–detection flow works in this project and how to reuse or modify it.

The goal is:
- Capture a photo from the camera.
- Run automatic detection of the main rectangular object (for example, a phone).
- Show the detected bounding box on top of the image.
- Allow the user to manually adjust if detection is not perfect.

---

### 1. Dependencies

We use the following packages:

- `camera` – live preview and image capture.
- `image` – CPU image processing (grayscale, blur, Sobel edges, etc.).
- `provider` – to share state (`MeasurementFlowProvider`) across screens.

These are already added in `pubspec.yaml`:

- `camera: ^0.11.0+2`
- `image: ^4.1.7`
- `provider: ^6.1.2`

If you are adding this flow to another project, ensure these packages are included and run:

```bash
flutter pub get
```

---

### 2. Capture an image from the camera

File: `lib/features/camera_capture/camera_capture_screen.dart`

Key parts:

- Initialize the back camera with `CameraController`.
- Show a full–screen `CameraPreview`.
- When the user taps **Capture**, take a picture and store the bytes in the shared provider.
- Navigate to the processing / detection step.

Important method:

```dart
Future<void> _capture() async {
  final XFile file = await _controller!.takePicture();
  final bytes = await file.readAsBytes();
  final flow = context.read<MeasurementFlowProvider>();
  flow.capturedImageBytes = bytes;
  flow.setCapturedImageSize(0, 0);
  Navigator.of(context).pushReplacementNamed('/processing');
}
```

This is where the camera image enters the detection pipeline.

---

### 3. Run object detection after capture

File: `lib/features/measurement/detection_screen.dart`

Responsibilities:

- Decode the captured image to get the pixel width/height.
- Call the detection function in `MeasurementService`.
- If detection succeeds, use the detected bounds.
- If detection fails, create a default rectangle and start in manual–edit mode.

Core flow:

```dart
Future<void> _runDetection() async {
  final flow = context.read<MeasurementFlowProvider>();
  final bytes = flow.capturedImageBytes;

  final decoded = img.decodeImage(bytes);
  final w = decoded.width;
  final h = decoded.height;
  flow.setCapturedImageSize(w, h);

  ObjectBounds? bounds = await flow.measurementService.detectObject(bytes);
  if (bounds == null) {
    // Fallback manual rectangle in the center
    bounds = ObjectBounds(
      center: Offset(w / 2.0, h / 2.0),
      halfWidth: w * 0.2,
      halfHeight: h * 0.2,
    );
  }

  setState(() {
    _imageWidth = w;
    _imageHeight = h;
    _bounds = bounds;
    _loading = false;
  });
}
```

This step connects the **raw image** to the **automatic detector**.

---

### 4. Automatic rectangle detection (image processing)

File: `lib/services/measurement_service.dart`

Function: `Future<ObjectBounds?> detectObject(Uint8List imageBytes)`

This runs in a background isolate using `compute` so the UI remains responsive.

Processing pipeline (`_detectObjectIsolate`):

1. **Decode and resize**
   - Decode JPEG bytes into an `image.Image`.
   - Resize so the longest side is at most 400 px (speeds up processing and keeps under ~300 ms).

2. **Grayscale**
   - Convert the small image to grayscale (`img.grayscale`).

3. **Gaussian blur + Sobel edges**
   - Apply `img.gaussianBlur(grayForEdges, radius: 2)` (~5×5 kernel).
   - Apply `img.sobel(grayForEdges)` to get edge magnitude.

4. **Build masks**
   - Edge mask: pixels where Sobel magnitude > edgeThreshold (strong edges).
   - Dark mask: pixels where grayscale intensity < darkThreshold (dark object on light background).
   - Combined mask: OR of edge mask and dark mask.

5. **Dilate**
   - One pass of dilation over the combined mask to connect broken edges and small gaps.

6. **Connected components (contours)**
   - Iterate all pixels in the dilated mask.
   - For each unvisited “1” pixel, run DFS/BFS to collect a component:
     - Count pixels.
     - Track minX, maxX, minY, maxY (bounding box).
   - Filter components:
     - Area scaled to original image > 5000 px.
     - Bounding box size ≥ 10×10.
     - Aspect ratio between 0.2 and 5.0.
     - Fill ratio (component area / bbox area) ≥ 0.2.
   - Keep the component with the largest area that passes filters.

7. **Refine inside the best component**
   - Re–scan only inside the best component’s box using the original mask.
   - Compute a tighter bounding box around the densest mask region.
   - This improves fit so the rectangle matches the actual phone rather than a very tall region.

8. **Map back to full resolution**
   - Convert the refined bounding box coordinates from the small image back to the original image using the inverse scale.
   - Build `ObjectBounds` from:
     - `center` = center of the box.
     - `halfWidth` and `halfHeight` = half the rectangle width/height in pixels.

9. **Return value and fallback**
   - If no valid component is found (or the rectangle is too small), return `null`.
   - The caller (`DetectionScreen`) then uses the manual rectangle instead.

Returned structure:

```dart
class ObjectBounds {
  final Offset center;
  final double halfWidth;
  final double halfHeight;
  final double angle; // currently 0 (axis–aligned)

  double get widthPx => halfWidth * 2;
  double get heightPx => halfHeight * 2;
}
```

From `ObjectBounds` you can derive corners:

```dart
final topLeft = Offset(
  bounds.center.dx - bounds.halfWidth,
  bounds.center.dy - bounds.halfHeight,
);
final topRight = Offset(
  bounds.center.dx + bounds.halfWidth,
  bounds.center.dy - bounds.halfHeight,
);
final bottomRight = Offset(
  bounds.center.dx + bounds.halfWidth,
  bounds.center.dy + bounds.halfHeight,
);
final bottomLeft = Offset(
  bounds.center.dx - bounds.halfWidth,
  bounds.center.dy + bounds.halfHeight,
);
```

---

### 5. Drawing the detection box and allowing manual adjustment

Two main places:

1. **Detection screen (manual editor) – `DetectionScreen`**
2. **Review screen (read–only overlay) – `ReviewScreen`**

#### 5.1 Manual editor (`DetectionScreen`)

Widget: `_MeasurementOverlay` in `lib/features/measurement/detection_screen.dart`

- Displays the captured image using `Image.memory`.
- Draws a green rectangle and blue crosshair with `_OverlayPainter`.
- Renders draggable handles for:
  - Moving the center.
  - Stretching width and height.
- On drag, it updates `ObjectBounds` and calls `onBoundsChanged`, which updates state in `_DetectionScreenState`.

This is the **manual fallback** if automatic detection is not accurate.

#### 5.2 Review overlay (`ReviewScreen`)

File: `lib/features/review/review_screen.dart`

- Shows the captured image and overlay using `MeasurementOverlayPainter`.
- Displays measurement info in `_ReviewPanel`:
  - **Image Size:** width × height (px).
  - **Object Width / Height:** in pixels.
  - **Converted Width / Height:** in cm and mm when calibration is available.
- Has buttons:
  - **Manual adjust** – goes back to `/detection` for fine–tuning.
  - **Recalculate** – re–runs processing.
  - **Confirm** – stores the final `DetectionResult` and navigates to `/result`.

---

### 6. Connecting detection to measurement and size conversion

After the user confirms:

1. `DetectionScreen._onConfirm` calls:
   - `measurementService.toMeasurementResult(...)` with:
     - `objectBounds` (pixels).
     - `scalePxPerMm` from calibration / reference.
   - Saves `MeasurementResult` and `DetectionResult` to `MeasurementFlowProvider`.

2. `ReviewScreen._confirm` also updates `DetectionResult` and `MeasurementResult` before navigating to the result screen.

This is where:

- **Pixel width/height** → **real–world mm/cm** using calibration.
- The converted size is available for matching against size charts.

---

### 7. Summary – How to add this pattern to another app

1. **Add dependencies**: `camera`, `image`, `provider`.
2. **Set up a state holder** (like `MeasurementFlowProvider`) with:
   - `capturedImageBytes`
   - `capturedImageWidth` / `capturedImageHeight`
   - `objectBounds`
3. **Create a camera screen**:
   - Show `CameraPreview`.
   - Capture photo → store bytes → navigate to detection screen.
4. **Create a detection screen**:
   - Decode the image, call `detectObject(imageBytes)`.
   - If result is null → create default manual rectangle.
   - Show image + overlay with draggable rectangle.
5. **Implement detection** (`detectObject`) using:
   - Grayscale → blur → edges + dark mask → dilation → connected components → best rectangle → map back to full size.
6. **Create a review screen**:
   - Show final box and sizes (px + cm/mm).
   - Offer **Manual adjust** in case automatic detection is not perfect.

This project already has all of these pieces wired together; you can use the files listed above as reference templates when integrating object detection into other camera flows.

