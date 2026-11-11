# 🌽 ChloroScan: Dual-Model Mobile Plant Pathology Diagnostic System

**ChloroScan** is an end-to-end computer vision and mobile solution engineered to assist smallholder farmers in the early detection, diagnosis, and management of maize crop diseases. Built with **Flutter (Dart)** for cross-platform delivery and integrated with **Firebase** (Authentication & Cloud Firestore), ChloroScan processes field-captured images through a sequential two-model deep learning architecture to filter non-leaf noise and accurately classify plant pathologies in real time.

---

## 📸 Disease Classification Targets

Model 2 evaluates validated maize leaf images across 5 distinct agronomic conditions:

| Class Index | Pathology / Disease Name | Botanical / Scientific Agent | Primary Symptoms & Field Indicators |
| :---: | :--- | :--- | :--- |
| **0** | **Healthy Leaf** | N/A | Normal green pigmentation, uniform leaf surface, zero lesion spots. |
| **1** | **Common Rust** | *Puccinia sorghi* | Small, powdery cinnamon-brown to golden pustules spread across upper/lower surfaces. |
| **2** | **Northern Corn Leaf Blight** | *Exserohilum turcicum* | Large, elongated grey-green or tan elliptical (cigar-shaped) lesions parallel to veins. |
| **3** | **Gray Leaf Spot** | *Cercospora zeae-maydis* | Rectangular tan/brown lesions strictly bounded by leaf veins, creating blocky spots. |
| **4** | **Fall Armyworm / Pest Damage** | *Spodoptera frugiperda* | Ragged defoliation, windowpane feeding patterns, irregular hole damage, and frass. |

---

## 🏗️ System Architecture & Dual-Model Pipeline

To maintain high diagnostic accuracy under unpredictable field conditions (poor lighting, background clutter, non-leaf objects), ChloroScan uses a strict two-stage inference workflow:

```text
  +-------------------------------------------------------------------+
  |                      Flutter Mobile App UI                        |
  |             (Camera Capture / Image Picker / Dashboard)           |
  +---------------------------------+---------------------------------+
                                    |
                                    v
  +-------------------------------------------------------------------+
  |               STAGE 1: Gatekeeper & Quality Filter                |
  |  - Model 1: One-Class SVM / MobileNetV3 Feature Extractor         |
  |  - Isolates leaf region & rejects out-of-distribution inputs       |
  +---------------------------------+---------------------------------+
                                    |
                                    +-----------------------+
                                    |                       |
                             [ Invalid / Noise ]    [ Valid Leaf ]
                                    |                       |
                                    v                       v
                         +--------------------+   +-------------------+
                         | Rejection Alert    |   | STAGE 2: Path-    |
                         | (Prompt Re-take)   |   | ology Classifier  |
                         +--------------------+   | (Model 2: PyTorch |
                                                  | ResNet50/MobileNet)|
                                                  +---------+---------+
                                                            |
                                                            v
  +-------------------------------------------------------------------+
  |                     Firebase Cloud Backend                        |
  |   - Auth: Firebase Authentication (User Session Management)       |
  |   - Firestore: Real-time Scan Logging & Treatment History Sync   |
  +-------------------------------------------------------------------+
