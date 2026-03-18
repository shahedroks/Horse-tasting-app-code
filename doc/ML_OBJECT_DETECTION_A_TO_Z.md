# ML-Based Object Detector – A থেকে Z গাইড

এই ডকুমেন্টে শূন্য থেকে শেষ পর্যন্ত ধাপে ধাপে লেখা আছে: **কী সফটওয়্যার লাগবে**, **কীভাবে ডেটা নেবে**, **মডেল কিভাবে বানাবে/ব্যবহার করবে**, এবং **Flutter অ্যাপে কিভাবে যোগ করবে**। তুমি কিছুই জানো না ধরে সব ব্যাপারটা এখানে দেওয়া হয়েছে।

---

## ধারণা সংক্ষেপে

- **Classical detector** = ছবির edge/contour দিয়ে বক্স বের করা (আমাদের বর্তমান Kotlin/Dart কোড)। অনেক ছবিতে কাজ করে, blur/কম কনট্রাস্টে ভুল ধরে।
- **ML detector** = একটা ছোট নিউরাল নেটওয়ার্ক (TFLite মডেল) ছবি নেয়, বক্স + confidence দেয়। ভালো ট্রেইন করলে blur/ব্যাকগ্রাউন্ডে বেশি ঠিক ধরে।
- **হাইব্রিড** = আগে classical চালাও → যদি আত্মবিশ্বাস কম হয় তাহলে ML চালাও → তাও না হলে manual adjust।

এই গাইডে আমরা **হাইব্রিড** সেটআপ করব: অ্যাপে একটা TFLite মডেল যোগ করব এবং classical এর পরে ML fallback দেব।

---

## Part 0: তোমার কম্পিউটারে যা লাগবে

| জিনিস | কেন লাগবে | কোথা থেকে |
|--------|-----------|------------|
| **Python 3.8–3.11** | মডেল ট্রেইন/কনভার্ট করার টুলগুলো Python এ চলে | [python.org](https://www.python.org/downloads/) |
| **pip** | Python প্যাকেজ ইনস্টল (প্রায়ই Python এর সাথেই আসে) | `python -m ensurepip` |
| **Flutter SDK** | অ্যাপ বিল্ড করা (আগে থেকেই থাকবে) | ইতিমধ্যে আছে |
| **একটি টেক্সট এডিটর** | স্ক্রিপ্ট/কনফিগ এডিট (VS Code / Notepad যেকোনোটা) | ইতিমধ্যে আছে |

চেক করো:

```bash
python --version
pip --version
flutter --version
```

সব ঠিক থাকলে পরের ধাপে যাও।

---

## Part 1: দুইটা রাস্তা – কোনটা নেবে?

### রাস্তা A: প্রি-ট্রেইনড মডেল দিয়ে দ্রুত শুরু (ট্রেইনিং ছাড়া)

- **কখন নেবে:** এখনই অ্যাপে ML দেখতে চাও, নিজে ডেটা/ট্রেইন করবে না।
- **কাজ:** একটা ছোট object detection মডেল (যেমন COCO-SSD বা অনুরূপ) ডাউনলোড করে TFLite এ কনভার্ট করবে অথবা ইতিমধ্যে কনভার্ট করা `.tflite` ফাইল ব্যবহার করবে। ফোন/বক্স/প্যাকেট “object” হিসেবে ধরা যাবে, কিন্তু তোমার নিজের কাস্টম অবজেক্টের জন্য নিখুঁত নাও হতে পারে।
- **সময়:** ৩০ মিন – ১ ঘণ্টা।

### রাস্তা B: নিজের ডেটা দিয়ে মডেল ট্রেইন (A–Z সঠিকভাবে)

- **কখন নেবে:** ফোন/বক্স/প্যাকেটের জন্য **সঠিক এবং নির্ভরযোগ্য** ডিটেকশন চাই।
- **কাজ:** নিজে ছবি তুলে/জোগাড় করে লেবেল করবে → ট্রেইন করবে → TFLite এ রূপান্তর করবে → অ্যাপে বসাবে।
- **সময়:** প্রথমবার ১–২ দিন (ডেটা + ট্রেইন + ইন্টিগ্রেশন)।

নিচে **দুটো রাস্তার জন্যই** ধাপগুলো আলাদা করে দেওয়া আছে। রাস্তা A দিয়ে শুরু করলে দ্রুত অ্যাপে ML চালু দেখতে পারবে; পরে চাইলে রাস্তা B এ গিয়ে নিজের মডেল বানাতে পারবে।

---

## Part 2: রাস্তা A – প্রি-ট্রেইনড মডেল দিয়ে শুরু

### ধাপ A.1: TFLite মডেল ফাইল জোগাড় করা

১. ব্রাউজার খোলো এবং যেকোনো একটা সোর্স থেকে একটা **object detection** TFLite মডেল ডাউনলোড করো। উদাহরণ (Google এর):

   - [TF Hub – SSD MobileNet](https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/2) – এখান থেকে “Download” বা “TFLite” লিংক খুঁজে `.tflite` ফাইল ডাউনলোড করো।
   - অথবা [TensorFlow Lite – Pre-trained models](https://www.tensorflow.org/lite/examples/object_detection/overview) পেজ থেকে “Download” করে যে ফাইলটা object detection এর জন্য দেওয়া আছে সেটা নাও।

২. ডাউনলোড করা ফাইলের নাম হতে পারে যেমন: `detect.tflite` বা `ssd_mobilenet_v1.tflite`।

৩. Flutter প্রজেক্টে অ্যাপের অ্যাসেট ফোল্ডারে মডেল রাখো:

   - প্রজেক্ট রুটে `assets` ফোল্ডার আছে (যেখানে `assets/size_chart.json` ইত্যাদি থাকে)।
   - তার ভেতরে একটা ফোল্ডার বানাও: `assets/models`।
   - ডাউনলোড করা `.tflite` ফাইলটা কপি করে `assets/models/detect.tflite` নামে রাখো।

৪. `pubspec.yaml` এ অ্যাসেট রেজিস্টার করো:

   ```yaml
   flutter:
     assets:
       - assets/
       - assets/models/
       - assets/models/detect.tflite
   ```

   তারপর কমান্ড চালাও:

   ```bash
   flutter pub get
   ```

এটাই রাস্তা A এর মডেল সেটআপ। এরপর Part 4 এ গিয়ে Flutter এ মডেল লোড ও ইনফারেন্স করার কোড যোগ করবে।

---

## Part 3: রাস্তা B – নিজের ডেটা দিয়ে মডেল ট্রেইন (A–Z)

### ধাপ B.1: ছবি সংগ্রহ (Dataset)

১. **কী ধরনের অবজেক্ট ডিটেক করবে** ঠিক করো (যেমন: শুধু ফোন, বা শুধু সিগারেট প্যাকেট, বা সব ধরনের বক্স)।

২. **কমপক্ষে ১০০–২০০টা ছবি** নাও যেখানে ওই অবজেক্ট আছে। বেশি ছবি = ভালো মডেল।
   - ফোন দিয়ে নিজেই তুলো (বিভিন্ন কোণ, আলো, ব্যাকগ্রাউন্ড)।
   - অথবা ইন্টারনেট থেকে ফ্রি ছবি ডাউনলোড করে ব্যবহার করো (কপিরাইট মেনে)।

৩. সব ছবি একটা ফোল্ডারে রাখো, যেমন: `C:\my_dataset\images\`।  
   ফাইলের নাম সহজ রাখো: `img_001.jpg`, `img_002.jpg`, …।

### ধাপ B.2: লেবেলিং (বাউন্ডিং বক্স দেয়া)

প্রতিটি ছবিতে “অবজেক্ট কোথায়” সেটা বক্স আঁকতে হবে। এটাই লেবেলিং।

১. টুল ইনস্টল করো – **labelImg** (Python দিয়ে চলে):

   ```bash
   pip install labelImg
   ```

২. চালু করো:

   ```bash
   labelImg
   ```

৩. **Open Dir** দিয়ে `C:\my_dataset\images` সিলেক্ট করো।  
   **Change Save Dir** দিয়ে একই ফোল্ডার বা `C:\my_dataset\labels` সিলেক্ট করো (যেখানে XML বা TXT সেভ হবে)।

৪. প্রতিটি ছবিতে:
   - **W** চাপো (Create RectBox)।
   - অবজেক্টের চারপাশে একটা আয়তক্ষেত্র টেনে আঁকো।
   - ক্লাস নাম দাও, যেমন: `object` বা `phone`।
   - সেভ করো (Ctrl+S)। পরের ছবিতে চলে যাও।

৫. সব ছবি লেবেল করা পর্যন্ত repeat করো।  
   সেভ করার পর প্রতিটি ছবির জন্য একটা `.xml` (PascalVOC) বা `.txt` (YOLO format) ফাইল তৈরি হবে। আমরা পরে স্ক্রিপ্ট দিয়ে এগুলো ট্রেইনিং ফরম্যাটে কনভার্ট করতে পারব।

### ধাপ B.3: ট্রেইনিং স্ক্রিপ্ট (Python এ)

ট্রেইনিং এর জন্য TensorFlow / Keras বা TensorFlow Lite Model Maker ব্যবহার করা যায়। সবচেয়ে সহজ উপায় **TensorFlow Lite Model Maker**।

১. প্যাকেজ ইনস্টল:

   ```bash
   pip install tflite-model-maker
   ```

২. নিচের মত একটা ফোল্ডার স্ট্রাকচার বানাও:

   ```
   C:\my_dataset\
     images\     ← সব ছবি
     labels\      ← প্রতিটি ছবির জন্য .xml (PascalVOC)
   ```

   যদি তুমি labelImg এ PascalVOC ফরম্যাটে সেভ করে থাকো তাহলে প্রতিটি ছবির পাশে একই নামে `.xml` থাকবে (অথবা labels ফোল্ডারে)।

৩. একটা Python স্ক্রিপ্ট লিখো, যেমন `train_detector.py`:

   ```python
   # train_detector.py
   from tflite_model_maker import model_spec
   from tflite_model_maker import object_detector
   import os

   # ডেটা ফোল্ডার (তোমার পাথ দাও)
   data_dir = r'C:\my_dataset'
   # সব ছবি একটা ফোল্ডারে, এবং একটা CSV বা XML লিস্ট যেখানে image path + bbox আছে
   # Model Maker কখনও কখনও নির্দিষ্ট ফরম্যাট চায়; নিচের লিংক দেখো
   train_data = object_detector.DataLoader.from_pascal_voc(
       os.path.join(data_dir, 'images'),
       os.path.join(data_dir, 'labels'),
       ['object']  # ক্লাস নাম যেটা labelImg এ দিয়েছ
   )

   spec = model_spec.get('efficientdet_lite0')
   model = object_detector.create(train_data, model_spec=spec, epochs=20, batch_size=8)
   model.export(export_dir='export', tflite_filename='detect.tflite')
   ```

   Model Maker এর exact API সময়ের সাথে বদলাতে পারে। অফিসিয়াল ডকুমেন্ট দেখো:  
   [TensorFlow Lite Model Maker – Object detection](https://www.tensorflow.org/lite/models/modify/model_maker/object_detection)

৪. রান করো:

   ```bash
   python train_detector.py
   ```

৫. ট্রেইন শেষ হলে `export/detect.tflite` পাবে। এই ফাইলটা কপি করে Flutter প্রজেক্টে `assets/models/detect.tflite` এ রাখো এবং `pubspec.yaml` এ অ্যাসেট যোগ করো (Part 2 এর ধাপ A.1 এর শেষের মত)।

---

## Part 4: Flutter অ্যাপে মডেল ও TFLite যোগ করা

### ধাপ 4.1: প্যাকেজ যোগ করা

`pubspec.yaml` এর `dependencies` সেকশনে যোগ করো:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... বাকি সব থাকবে
  tflite_flutter: ^0.10.4
```

তারপর:

```bash
flutter pub get
```

### ধাপ 4.2: অ্যাসেটে মডেল রাখা (আগেই করেছ যদি)

নিশ্চিত করো:

- ফাইল আছে: `assets/models/detect.tflite`
- `pubspec.yaml` এ লেখা আছে:

  ```yaml
  flutter:
    assets:
      - assets/
      - assets/models/
      - assets/models/detect.tflite
  ```

### ধাপ 4.3: ML ডিটেক্টর সার্ভিস (Dart কোড)

প্রজেক্টে একটা নতুন ফাইল বানাও যেটা শুধু TFLite মডেল লোড করে এবং একটা ছবি দিলে বাউন্ডিং বক্স রিটার্ন করে।

ফাইল পাথ: `lib/services/ml_object_detector.dart`

এই ফাইলের ভেতরে:

- `Interpreter` দিয়ে `assets/models/detect.tflite` লোড করবে।
- ইনপুট হিসেবে ছবির bytes নেবে, প্রি-প্রসেস করবে (রিসাইজ/নরমালাইজ – মডেলের ইনপুট সাইজ অনুযায়ী, সাধারণত 300x300 বা 320x320)।
- `interpreter.run()` চালিয়ে আউটপুট পাবে (বক্স কোঅর্ডিনেট + ক্লাস + স্কোর)।
- আউটপুট পার্স করে সবচেয়ে confident ডিটেকশনটা নিয়ে `ObjectBounds` (center, halfWidth, halfHeight) বানিয়ে রিটার্ন করবে।

কোন মডেল ব্যবহার করেছ (SSD MobileNet ইত্যাদি) তার উপর ভিত্তি করে ইনপুট/আউটপুট শেপ ও নরমালাইজেশন একটু আলাদা হবে। তাই এই গাইডে আমরা **কোন একটা উদাহরণ মডেল** ধরে নিয়ে নিচে একটা স্যাম্পল স্ট্রাকচার দিচ্ছি; তুমি নিজের মডেলের ইনপুট/আউটপুট ম্যাচ করে এডজাস্ট করবে।

**উদাহরণ স্ট্রাকচার (SSD-জাতীয় মডেলের জন্য):**

- ইনপুট: `[1, 300, 300, 3]` (RGB, নরমালাইজড 0–1 বা -1 to 1, মডেল অনুযায়ী)।
- আউটপুট: location + category + score (মডেল মেটাডেটা বা ডকুমেন্ট দেখে ঠিক করো)।
- location কে ইমেজের আসল width/height এ স্কেল করে center, halfWidth, halfHeight বের করো।

বাস্তবে `ml_object_detector.dart` তে যা থাকবে (সংক্ষেপে):

- `init()` – একবার মডেল লোড।
- `Future<ObjectBounds?> detect(Uint8List imageBytes, int imageWidth, int imageHeight)` – ছবি দিলে একটা বক্স রিটার্ন; না পেলে `null`।
- মডেলের ইনপুট সাইজ ও ক্লাস সংখ্যা constants হিসেবে উপরে লিখে রাখো।

এই ফাইলটা আমি পরের ধাপে একটা কংক্রিট উদাহরণ দিয়ে লিখে দেব যাতে তুমি শুধু মডেল পাথ আর শেপ মিলিয়ে নিতে পারো।

### ধাপ 4.4: MeasurementService এ হাইব্রিড লজিক

`lib/services/measurement_service.dart` এ `detectObject` এর ভেতরে লজিক হবে:

১. আগে **classical (অথবা Kotlin নেটিভ)** চালাও যেমন এখন করছ।
২. যদি রেজাল্ট পেয়ে যাও এবং quality/confidence ঠিক মনে করো (যেমন বক্স ছবির ৮০% এর কম জায়গা নেয়, aspect ratio রেঞ্জের ভেতরে) তাহলে সেটাই রিটার্ন করো।
৩. অন্যথায় **ML detector** চালাও: `MlObjectDetector.detect(imageBytes, width, height)`।
৪. ML থেকে বক্স পেলে সেটা `ObjectBounds` বানিয়ে রিটার্ন করো।
৫. তাও না পেলে `null` রিটার্ন করো – UI তখন manual adjust দেখাবে।

এভাবে প্রথমে classical, তারপর ML, শেষে manual – এই ফ্লোটা সম্পূর্ণ A–Z হয়ে যাবে।

---

## Part 5: ধাপে ধাপে চেকলিস্ট (তুমি যেন ভুলে না যাও)

নিচের লিস্ট টিক দিয়ে যাও:

**রাস্তা A (প্রি-ট্রেইনড):**

- [ ] Python + pip ইনস্টল ও চেক করা।
- [ ] একটা object detection TFLite মডেল ডাউনলোড করা।
- [ ] মডেল কপি করে `assets/models/detect.tflite` এ রাখা।
- [ ] `pubspec.yaml` এ `assets/models/detect.tflite` অ্যাসেট ও `tflite_flutter` যোগ করা।
- [ ] `lib/services/ml_object_detector.dart` বানানো এবং মডেল লোড + ইনফারেন্স কোড লেখা (ইনপুট/আউটপুট নিজের মডেল অনুযায়ী)।
- [ ] `measurement_service.dart` এ classical → ML → null ফ্লো যোগ করা।
- [ ] অ্যাপ রান করে ক্যামেরা থেকে ক্যাপচার করে টেস্ট করা।

**রাস্তা B (নিজের মডেল):**

- [ ] Part 5 রাস্তা A এর প্রথম দুই বুলেট করা।
- [ ] কমপক্ষে ১০০–২০০ ছবি জোগাড় করা।
- [ ] labelImg দিয়ে সব ছবিতে বক্স দিয়ে লেবেল করা।
- [ ] ট্রেইনিং স্ক্রিপ্ট (Model Maker বা নিজের ট্রেইনিং কোড) চালিয়ে `detect.tflite` বানানো।
- [ ] বানানো মডেল `assets/models/detect.tflite` এ রাখা।
- [ ] বাকি সব রাস্তা A এর মত: `tflite_flutter`, `ml_object_detector.dart`, `measurement_service.dart` হাইব্রিড।

---

## Part 6: সমস্যা সমাধান (যেগুলো প্রায়ই হয়)

- **মডেল লোড হচ্ছে না:**  
  চেক করো `pubspec.yaml` এ `assets/models/detect.tflite` ঠিকভাবে আছে কিনা এবং `flutter clean` পরে আবার `flutter pub get` ও রান দিয়েছ কিনা।

- **ইনফারেন্সে ক্র্যাশ / ভুল রেজাল্ট:**  
  মডেলের **ইনপুট শেপ** (উচ্চতা, প্রস্থ, চ্যানেল) এবং **নরমালাইজেশন** (0–1 নাকি -1–1) ডকুমেন্ট বা মেটাডেটা মেনে `ml_object_detector.dart` এ দিয়েছ কিনা দেখো। আউটপুট টেনসরের শেপ ও মান (বক্স ফরম্যাট: normalized নাকি pixel) মডেল অনুযায়ী পার্স করো।

- **অ্যান্ড্রয়েডে লাইব্রেরি এরর:**  
  `android/app/build.gradle.kts` এ `minSdk` কমপক্ষে 21 রাখো। TFLite এর অফিসিয়াল রিকোয়ারমেন্ট চেক করো।

- **ট্রেইনিং এরর (রাস্তা B):**  
  ডেটা পাথ সঠিক কিনা, লেবেল ফাইলগুলো (XML/TXT) সঠিক ফরম্যাটে কিনা দেখো। Model Maker এর উদাহরণ ডকুমেন্ট অনুসরণ করো।

---

## সংক্ষেপে

- **A থেকে Z মানে:**  
  সফটওয়্যার সেটআপ → ডেটা (রাস্তা B তে) → লেবেলিং (রাস্তা B) → ট্রেইন/কনভার্ট (রাস্তা B) অথবা প্রি-ট্রেইনড মডেল (রাস্তা A) → Flutter এ মডেল অ্যাসেট ও `tflite_flutter` → `ml_object_detector.dart` → `measurement_service.dart` এ classical → ML → manual ফ্লো।

---

## Part 7: কোড স্কেচ – কোথায় কী লিখবে

### ফাইল ১: `lib/services/ml_object_detector.dart`

এই ফাইলটা তুমি প্রজেক্টে বানাবে। ভেতরে যা থাকবে (সংক্ষেপে):

- `import 'package:tflite_flutter/tflite_flutter.dart';` এবং `dart:typed_data`, `dart:ui' show Offset`.
- একটা ক্লাস `MlObjectDetector` যাতে:
  - `static Interpreter? _interpreter;`
  - `static Future<void> init()` – `rootBundle` থেকে `assets/models/detect.tflite` লোড করে `Interpreter.fromBuffer(...)` দিয়ে `_interpreter` সেট করবে।
  - `static Future<ObjectBounds?> detect(Uint8List imageBytes, int imageWidth, int imageHeight)` – ছবি ডিকোড করে মডেলের ইনপুট সাইজে (যেমন 300x300) রিসাইজ ও নরমালাইজ করবে, তারপর `_interpreter.run(input, output)` চালাবে। আউটপুট থেকে বক্স পার্স করে সবচেয়ে confident ডিটেকশনটা নিয়ে ইমেজের আসল সাইজে স্কেল করে `ObjectBounds(center: Offset(cx, cy), halfWidth: hw, halfHeight: hh)` রিটার্ন করবে। কোনো ডিটেকশন না থাকলে বা confidence কম থাকলে `null` রিটার্ন।
- মডেলের ইনপুট/আউটপুট শেপ তুমি নিজের মডেল অনুযায়ী সেট করবে (সাধারণত SSD এর জন্য input `[1, 300, 300, 3]`, output location + category + score)।

### ফাইল ২: `lib/services/measurement_service.dart` – শুধু পরিবর্তন

`detectObject` এর ভেতরে লজিক হবে:

1. আগে যেমন আছে (Android এ নেটিভ, অন্যথায় Dart classical) চালাও। রেজাল্ট পেলে একে “candidate” ধরো।
2. (ঐচ্ছিক) candidate এর quality চেক করো (যেমন বক্স এরিয়া ছবির ৮০% এর নিচে কিনা)। ভালো থাকলে এই candidate টাই রিটার্ন করো।
3. ভালো candidate না থাকলে অথবা classical রেজাল্ট null হলে `MlObjectDetector.detect(imageBytes, width, height)` কল করো। আগে একবার `MlObjectDetector.init()` ডাকতে হবে (যেমন অ্যাপ স্টার্টে বা প্রথম detection এর আগে)।
4. ML থেকে বক্স পেলে সেটা রিটার্ন করো।
5. তাও null হলে `null` রিটার্ন – UI manual adjust দেখাবে।

### অ্যাপ স্টার্টে ML ইনিট

`main.dart` বা যে জায়গায় অ্যাপ শুরুর সময় একবার কোড চলে (যেমন `MeasurementFlowProvider` বা হোম স্ক্রিনের `initState`), সেখানে `MlObjectDetector.init()` একবার ডাকো। ব্যর্থ হলে (মডেল নেই বা লোড এরর) catch করে নাও, তাহলে অ্যাপ শুধু classical + manual দিয়ে চলবে।

---

এই ডকুমেন্ট অনুসরণ করলে তুমি প্রথম থেকে শেষ পর্যন্ত কী কী করতে হবে সেটা ধাপে ধাপে পাবে। `ml_object_detector.dart` এর পূর্ণ উদাহরণ কোড চাইলে বলো – তখন তোমার মডেলের exact ইনপুট/আউটপুট ধরে একটা ভার্সন লিখে দেব।
