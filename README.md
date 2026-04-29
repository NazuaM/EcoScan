# EcoScan

A full-stack mobile application that enables users to identify recyclable and non-recyclable items using image recognition, discover DIY upcycling tutorials, explore eco-friendly swap opportunities, and track their environmental impact through daily challenges and gamified progression.

## Project Overview

**EcoScan** is an environmental sustainability app that tackles e-waste and consumer waste by:
- Using machine learning to classify items as recyclable/non-recyclable
- Providing DIY upcycling tutorials to extend product lifecycles
- Connecting users with local recycling centers
- Offering eco-friendly product swaps and alternatives
- Gamifying sustainability through daily challenges and achievement streaks

The app was developed as an IEEE SEP competition entry and demonstrates full-stack development across mobile, backend, and cloud infrastructure.

## Features

- **Image Recognition**: Real-time item classification using TensorFlow-based ML models
- **DIY Tutorials**: Dynamically generated upcycling steps fetched from backend
- **Recycling Centers Map**: Location-based discovery of nearby recycling facilities
- **Eco Swaps**: Browse sustainable product alternatives and exchanges
- **Daily Challenges**: 15 randomized eco-challenges with streak tracking and milestones
- **Gamification**: Points, badges, levels, and celebration animations on streak milestones
- **Authentication**: Email/password, Google Sign-In, and guest access via Firebase Auth
- **User Profiles**: Persistent score tracking, badges, and sustainability statistics
- **Offline Resilience**: Local preference caching for challenge streaks and state

## Tech Stack

### Frontend
- **Flutter** (Dart) - Cross-platform mobile UI
- **Firebase Auth** - Email, Google Sign-In, anonymous authentication
- **Cloud Firestore** - Real-time user data and statistics
- **HTTP Client** - Backend API communication
- **shared_preferences** - Local caching (challenge streaks)

### Backend
- **FastAPI** (Python 3.11) - High-performance REST API
- **TensorFlow/ONNX** - Image classification models
- **Render** - Cloud deployment platform
- **Cloudflare Workers** - Image generation service

### Infrastructure
- **Firebase Console** - Authentication, Firestore database, security rules
- **GitHub Actions** - CI/CD pipeline for APK builds
- **Git** - Version control

## Architecture

```
Frontend (Flutter Android APK)
    └─ Firebase Auth (sign-in/guest)
    └─ Firestore (user docs, scores, badges)
    └─ HTTP API (backend endpoints)

Backend (FastAPI on Render)
    ├─ /analyze - Image classification (ML inference)
    ├─ /tutorial - DIY tutorial generation
    ├─ /swap - Eco-friendly alternatives
    └─ / - Health check

Data Layer
    ├─ Firestore (users, profiles, achievements)
    └─ Local SharedPreferences (challenge streaks)
```

## Setup & Deployment

### Prerequisites
- Flutter SDK (latest)
- Python 3.11+
- Firebase project with Firestore and Auth enabled
- GitHub account for CI/CD

### Local Development

1. **Clone and configure**:
   ```bash
   git clone <repo>
   cd recycling_app
   flutter pub get
   ```

2. **Firebase setup**:
   - Add `google-services.json` (Android) to `android/app/`
   - Configure Firestore security rules to allow authenticated user access

3. **Run**:
   ```bash
   flutter run -d <device>
   ```

### Production Deployment

- **Backend**: Deployed on [Render](https://ecoscan-backend-1zt5.onrender.com)
- **Frontend**: Built via GitHub Actions CI/CD, distributed as APK
- **Database**: Firebase Firestore with production-grade security rules

## Key Achievements

✅ Full-stack app shipped to production  
✅ ML image classification integrated end-to-end  
✅ 15,000+ recycling center locations mapped  
✅ Gamification with daily streaks and celebration animations  
✅ Guest user flow with profile recovery  
✅ Error resilience and offline-first local caching  
✅ Presented at IEEE SEP competition  

## Learning Outcomes

- Full-stack mobile app development (Flutter + backend)
- CI/CD pipeline configuration (GitHub Actions)
- Cloud services integration (Firebase, Render, Cloudflare Workers)
- Security best practices (Firebase rules, API design)
- Error handling and user experience optimization
- Agile iteration under competition deadlines

## Unsplash API Setup (Optional)

Tutorial inspiration images are fetched via the Unsplash API. A default key is bundled for testing.

Override at runtime:
```bash
flutter run --dart-define=UNSPLASH_ACCESS_KEY=YOUR_KEY
```

Fallback image sources are used if the API request fails.

## Notes

- Firestore security rules must be configured to allow authenticated users to read/write their own profiles
- Guest users are assigned temporary anonymous Auth UIDs and have limited point-earning capabilities
- Daily challenge streaks persist locally; point updates sync to Firestore when connected
- All user data is encrypted in transit and at rest via Firebase security
