Build a complete Flutter mobile app (Android + iOS) that uses the device camera to capture an image and measure the real-world width and height of a round/circular object in the image, then determine the closest size from a provided size chart.

Important rule:
Do NOT guess real-world mm/cm from a single image without calibration. The app must require either:
1. a known-size reference object in the same image and same plane as the target object, or
2. a fixed calibration mode with a known camera distance and on-screen guide.
If neither is available, show a clear message: “Accurate real-world measurement is not possible without a reference or calibration.”

Technical constraints:
- Flutter only
- No backend
- No cloud API
- No OCR for the size chart at runtime
- Store the size chart as local structured data (JSON / Dart model)
- Clean, production-ready Flutter code
- Null safety enabled
- Good architecture and readable code
- Use Flutter packages only
- Prefer pure Flutter/Dart where possible
- Manual correction UI is required if auto detection is imperfect

Main app goal:
1. Open camera preview
2. User captures image of a round object
3. App detects the target object
4. App measures:
   - horizontal size = width
   - vertical size = height / heel-to-toe
5. Convert pixel dimensions to real mm using reference/calibration
6. Compare measured values with the size chart
7. Return the closest matching size
8. Show measurement details and allow manual adjustment

Required app flow:
1. Home screen
   - Button: Start Measurement
   - Button: View Size Chart
   - Button: Calibration Settings

2. Category selection screen
   User selects one category:
   - MINI
   - FRONTS
   - DRAFT
   - SPORTSHU
   - HINDS

3. Capture instructions screen
   Show clear instructions:
   - Place the round object on a flat surface
   - Keep camera straight above the object
   - Avoid angled shots
   - Keep the reference object in the same plane as the target
   - Ensure good lighting
   - Fit both object and reference fully inside the frame

4. Camera capture screen
   - Live camera preview
   - Overlay guide frame
   - Capture photo
   - Retake photo option

5. Detection and measurement screen
   The app should:
   - Try to detect the round object automatically
   - Try to detect the reference object automatically
   - If auto detection is not reliable, allow manual adjustment:
     - Drag left, right, top, bottom handles
     - Or drag ellipse/circle boundary handles
   - Show overlay on top of image using CustomPainter
   - Show measured pixel width and pixel height
   - Convert px to mm using calibration

6. Result screen
   Show:
   - measured width in mm
   - measured height in mm
   - best matched size
   - selected category
   - difference from nearest chart row
   - alternative nearest sizes
   - confidence / warning if accuracy is low

Measurement rules:
- Width = horizontal diameter or max horizontal dimension of the object
- Height = vertical diameter or heel-to-toe dimension
- Map measured width to chart “WIDTH (mm)”
- Map measured height to chart “HEEL-TOE (mm)”

Calibration logic:
Implement two measurement modes.

Mode A: Reference object mode (recommended)
- Require a known-size object in the image
- Example reference:
  - credit card = 85.60 mm x 53.98 mm
  - A4 sheet = 210 mm x 297 mm
  - ruler = user-defined visible segment
- Let user choose reference type before capture
- Detect the reference or allow the user to mark its corners manually
- Use it to calculate pixel-to-mm scale
- If the reference is rectangular, also support perspective correction

Mode B: Fixed calibration mode
- User performs a one-time calibration at a fixed camera distance
- Save pixels-per-mm ratio
- Warn user that this mode is less accurate if distance/angle changes

Perspective and accuracy rules:
- Add perspective correction if reference corners are available
- Warn user if image angle is too high
- Warn if object and reference do not appear on same plane
- Warn if object edges are blurry or partially outside the frame
- Never output “accurate mm” when detection quality is too poor

Detection strategy:
- First attempt automatic detection of the circular object
- If needed, use contour detection / edge detection / ellipse fitting / bounding box
- Fallback to manual adjustment UI
- The final measurement must always be user-reviewable before result submission

Size matching logic:
- Use nearest-match comparison against rows in the selected category
- Compare both width and heel-to-toe
- Use a distance formula such as:
  score = sqrt((measuredWidthMm - row.widthMm)^2 + (measuredHeightMm - row.heelToeMm)^2)
- Choose the row with the lowest score
- Also show the second and third nearest sizes
- If measurement sits between two sizes, show a warning like:
  “This measurement is between Size X and Size Y”

Use this exact local size chart data:

{
  "MINI": [
    { "size": "75", "widthMm": 75, "heelToeMm": 70 },
    { "size": "85", "widthMm": 85, "heelToeMm": 80 },
    { "size": "95", "widthMm": 95, "heelToeMm": 90 },
    { "size": "100", "widthMm": 100, "heelToeMm": 105 }
  ],
  "FRONTS": [
    { "size": "5x0", "widthMm": 105, "heelToeMm": 108 },
    { "size": "4x0", "widthMm": 113, "heelToeMm": 113 },
    { "size": "3x0", "widthMm": 120, "heelToeMm": 120 },
    { "size": "00", "widthMm": 125, "heelToeMm": 125 },
    { "size": "0", "widthMm": 135, "heelToeMm": 130 },
    { "size": "1", "widthMm": 140, "heelToeMm": 135 },
    { "size": "2", "widthMm": 145, "heelToeMm": 140 },
    { "size": "3", "widthMm": 150, "heelToeMm": 145 },
    { "size": "4", "widthMm": 155, "heelToeMm": 155 },
    { "size": "5", "widthMm": 165, "heelToeMm": 174 }
  ],
  "DRAFT": [
    { "size": "6", "widthMm": 172, "heelToeMm": 181 },
    { "size": "7", "widthMm": 178, "heelToeMm": 180 },
    { "size": "8", "widthMm": 202, "heelToeMm": 204 }
  ],
  "SPORTSHU": [
    { "size": "5", "widthMm": 130, "heelToeMm": 120 },
    { "size": "6", "widthMm": 135, "heelToeMm": 125 },
    { "size": "7", "widthMm": 138, "heelToeMm": 130 }
  ],
  "HINDS": [
    { "size": "5x0", "widthMm": 100, "heelToeMm": 108 },
    { "size": "4x0", "widthMm": 108, "heelToeMm": 116 },
    { "size": "3x0", "widthMm": 112, "heelToeMm": 122 },
    { "size": "00", "widthMm": 120, "heelToeMm": 125 },
    { "size": "0", "widthMm": 125, "heelToeMm": 130 },
    { "size": "1", "widthMm": 130, "heelToeMm": 138 },
    { "size": "2", "widthMm": 138, "heelToeMm": 143 },
    { "size": "3", "widthMm": 143, "heelToeMm": 150 },
    { "size": "4", "widthMm": 151, "heelToeMm": 166 }
  ]
}

UI/UX requirements:
- Clean modern UI
- Clear camera guides
- Overlay measurement lines on image
- Easy manual editing
- Error states with helpful message
- Show “measurement quality” status:
  - Good
  - Medium
  - Poor

Recommended Flutter features/packages:
- camera
- image_picker (optional fallback)
- CustomPainter
- image package for image processing
- local JSON or Dart models for size chart
- state management with Provider / Riverpod / Bloc (choose one and keep it clean)

Project structure:
- features/
  - camera_capture/
  - calibration/
  - measurement/
  - size_matching/
  - size_chart/
- models/
- services/
- widgets/
- utils/

What I want from you:
1. A full Flutter project structure
2. All Dart models
3. Measurement service
4. Calibration service
5. Size matching service
6. Camera screen
7. Detection review screen with manual adjustment
8. Result screen
9. Local size chart data integration
10. Clean commented code
11. Clear explanation of how measurement works
12. Important warnings where accuracy can fail

Critical honesty rule:
- Never pretend that real mm measurement is accurate without reference/calibration
- If required data is missing, show a warning instead of returning a fake size

Please generate the implementation step by step, starting with:
1. package list
2. folder structure
3. models
4. calibration logic
5. measurement logic
6. UI screens
7. size matching logic
8. final integration