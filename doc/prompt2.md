Build a Flutter mobile app screen for camera capture and automatic object border detection from an image, based on this use case:

Use case:
- The user opens a camera screen with a centered capture guide box overlay
- The user captures a photo of a single main object placed roughly in the center
- The object is oval / round-like
- After capture, the app must automatically detect the object border and calculate its width and height
- The app must draw the detected border overlay on top of the image
- The app must show the measured width and height clearly
- First return width and height in pixels
- If calibration or reference is available, also convert to mm
- Flutter only
- No backend
- No cloud API

Important honesty rule:
- Do not fake real-world mm measurement from a single image without calibration or a known-size reference object
- If no calibration/reference is available, only show widthPx and heightPx
- Show a warning: “Real-world measurement requires calibration or a known-size reference”

Main requirement:
Create a complete Flutter implementation for:
1. Camera preview screen
2. Capture image
3. Crop to the overlay guide region
4. Automatically detect the main object inside the cropped region
5. Detect the outer border/contour of the object
6. Fit the best possible ellipse or rotated bounding rectangle around the object
7. Calculate:
   - widthPx
   - heightPx
   - center point
   - rotation angle
   - confidence score
8. Draw the detected border and measurement lines over the image
9. Show a review screen where the user can manually adjust the border if auto detection is slightly wrong
10. Prepare the result so it can later be matched with a local size chart

Detection goal:
- Detect the largest centered object inside the capture guide
- Ignore background items like keyboard, desk, hand, cables, etc.
- Focus on the object inside the guide frame
- Prioritize the object that is closest to the center of the capture box
- The object border should represent the outer visible boundary of the object

Recommended detection pipeline:
1. Capture image from camera
2. Crop image to the guide frame area
3. Preprocess image:
   - resize if needed
   - convert to grayscale
   - blur to reduce noise
   - edge detection
   - thresholding / contour extraction
4. Find contours
5. Filter contours by:
   - area
   - center proximity
   - shape similarity to oval / ellipse / rounded object
6. Choose the best contour
7. Fit ellipse or use minimum-area rotated bounding box
8. Compute object width and height from that fitted shape
9. Overlay the detected border on the preview result

Important fallback:
- If auto detection fails or confidence is low:
  - allow manual adjustment
  - user can drag left, right, top, bottom handles
  - or drag ellipse boundary handles
- Final measurement must always be editable before confirmation

Measurement output:
Return this result model:
- widthPx
- heightPx
- widthMm (nullable)
- heightMm (nullable)
- centerX
- centerY
- angle
- confidence
- detectionMethod
- hasCalibration
- warningMessage

Calibration support:
Support 2 modes:

Mode A: Pixel only
- No calibration
- Show widthPx and heightPx only

Mode B: Real measurement mode
- User provides calibration/reference
- Example:
  - credit card
  - ruler
  - A4 paper
  - custom known-size marker
- Use reference pixels to calculate pixelsPerMm
- Convert widthPx and heightPx to mm

Formula:
pixelsPerMm = referencePixels / referenceMm
widthMm = widthPx / pixelsPerMm
heightMm = heightPx / pixelsPerMm

UI requirements:
1. Camera screen
   - top app bar title: Capture Photo
   - centered translucent guide rectangle
   - capture button at bottom
   - zoom controls optional

2. Processing screen
   - loading indicator
   - “Detecting object border...”

3. Review screen
   - show captured image
   - draw detected border
   - draw width line and height line
   - show values:
     - Width: xxx px
     - Height: xxx px
   - if calibration exists:
     - Width: xxx mm
     - Height: xxx mm
   - manual adjust button
   - recalculate button
   - confirm button

4. Result screen
   - final detected width and height
   - confidence level:
     - Good
     - Medium
     - Poor
   - warning if measurement quality is low

Architecture requirements:
- Clean Flutter architecture
- Null safety
- Separate files for:
  - camera capture
  - image processing
  - border detection
  - measurement logic
  - calibration logic
  - result model
  - painter overlay
  - manual adjustment UI

Preferred implementation details:
- Use Flutter camera package for capture
- Use CustomPainter for border overlay and measurement lines
- Use local image processing in Flutter/Dart
- If needed, use a maintained Flutter-compatible OpenCV/image-processing solution
- No backend calls
- No cloud processing

Edge cases:
- Background clutter
- Dark image
- Partial object outside frame
- Object too small
- Object not centered
- Low contrast border
- Reflection/glare
- Multiple objects in frame

Rules for choosing the target object:
- Object must be inside the capture guide
- Prefer the largest object near the center
- Prefer oval / rounded contour
- Reject tiny contours and noisy edges
- Reject background objects near frame edges

Manual correction requirements:
- If auto border is inaccurate:
  - allow drag handles
  - update width and height live
  - preserve smooth UI performance

Code generation requirements:
Please generate this step by step:
1. pubspec dependencies
2. folder structure
3. models
4. camera capture screen
5. image crop-to-guide logic
6. border detection service
7. measurement service
8. CustomPainter overlay
9. manual adjustment screen
10. result screen
11. calibration support
12. final integration

Critical rule:
- First implement reliable border detection and width/height in pixels
- Then add optional mm conversion only when calibration/reference exists
- Do not guess real-world size without calibration

Expected final result:
A working Flutter app flow where the user captures a photo, the app automatically detects the main oval object border, draws the border, and shows the object width and height.