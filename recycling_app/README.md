# recycling_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Unsplash Setup (Tutorial Inspiration Images)

This app uses the Unsplash Search API for tutorial inspiration images.

1. A default Access Key is bundled so testers can run the app without extra setup.
2. You can optionally override the key at runtime with dart-define:

```bash
flutter run -d chrome --dart-define=UNSPLASH_ACCESS_KEY=YOUR_ACCESS_KEY
```

3. If the API request fails, the app automatically falls back to public placeholder image sources.

Security note: if a key is shared accidentally, rotate it in the Unsplash dashboard.
