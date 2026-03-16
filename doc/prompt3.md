You are a senior Flutter developer.

I am building a Flutter mobile app that measures real-world object dimensions using Augmented Reality. The current system uses pixel estimation, but I want to replace it with an AR-based measurement system using ar_flutter_plugin so measurements use real-world scale.

GOAL
Implement an AR measuring tool similar to Apple's Measure app.

The user will:
1. Open the AR camera
2. Tap one corner of the object
3. Tap another corner
4. The app calculates the real-world distance
5. Show measurement in centimeters and inches

TECH STACK
Flutter
ar_flutter_plugin
Riverpod (state management)
Firebase (optional for saving measurement history)

FEATURE REQUIREMENTS

AR SESSION
Initialize AR session using ARCore (Android) and ARKit (iOS).

Enable:
planeDetection: horizontal and vertical
showFeaturePoints: true
handleTaps: true

OBJECT MEASUREMENT FLOW

Step 1
User opens AR measurement screen.

Step 2
Camera scans environment and detects surfaces.

Step 3
User taps first point on object.

Create an AR anchor at that position.

Place a small 3D sphere marker.

Step 4
User taps second point.

Place another marker.

Step 5
Calculate distance between the two anchors using their world positions.

distance = sqrt(
(x2-x1)^2 +
(y2-y1)^2 +
(z2-z1)^2
)

Step 6
Convert meters to:

centimeters
inches

Step 7
Display measurement line between markers.

Show floating label above line with measurement value.

UI FEATURES

Display:
Live AR camera
Detected planes
Feature points

Markers:
Small spheres at selected points.

Measurement line:
3D line between points.

Floating label showing distance.

Controls:
Reset button
Confirm measurement
Save measurement

MEASUREMENT DISPLAY

Show:

Distance: 15.3 cm
Distance: 6.02 inches

Also show live measurement preview while placing points.

MULTI-POINT MODE

Allow measuring width and height by:

Point A → Point B = Width
Point B → Point C = Height

VISUALS

Use:
Red spheres for markers
Green line for measurement
White text label

PERFORMANCE

Keep AR session smooth at 60fps.

Only calculate measurement when two points exist.

ERROR HANDLING

If plane not detected:
Show message
"Move phone slowly to detect surfaces"

If tracking lost:
Show warning.

FILES TO CREATE

features/ar_measurement/

ar_measure_screen.dart
ar_measure_controller.dart
ar_measure_provider.dart
ar_measure_overlay.dart

CORE LOGIC

Function:

calculateDistance(Vector3 p1, Vector3 p2)

Return meters.

Convert to:

cm = meters * 100
inch = meters * 39.3701

AR NODE TYPES

Markers:
ARNode with sphere geometry.

Measurement line:
ARNode with cylinder geometry between points.

Floating label:
ARNode with text geometry.

UX REQUIREMENTS

Show instructions overlay:

"Move phone slowly to detect surface"
"Tap first point"
"Tap second point"

After measurement:

Show result card with:
Distance in cm
Distance in inches

Allow:
Reset
Save
Measure again

IMPORTANT

Do not simulate measurements.
Use real AR world coordinates.

Ensure anchors use worldTransform position.

OUTPUT

Generate full Flutter code using ar_flutter_plugin including:

AR session setup
tap detection
anchor creation
distance calculation
measurement line rendering
UI overlay