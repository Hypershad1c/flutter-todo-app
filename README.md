# 📱 Flutter To-Do App

A beautiful, cross-platform To-Do application built with Flutter, featuring local authentication, task management, and smart notifications. Works seamlessly on Android, iOS, and Web!

![Flutter](https://img.shields.io/badge/Flutter-3.24.3%2B-blue)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-green)
![License](https://img.shields.io/badge/license-MIT-orange)

## ✨ Features

### 🔐 **Local Authentication**
- Simple username & password authentication
- Credentials stored securely using `shared_preferences`
- Auto-login on subsequent app launches
- No internet required - completely offline

### ✅ **Task Management**
- Create, edit, and delete tasks
- Mark tasks as complete/incomplete
- Three priority levels (Low, Medium, High) with color coding
- Rich task descriptions
- Automatic sorting by creation date

### ⏰ **Smart Reminders**
- Set custom date and time reminders for tasks
- Local push notifications using `flutter_local_notifications`
- Notifications work even when app is closed
- Automatic notification cancellation when task is completed

### 📊 **History Tracking**
- View all completed tasks with timestamps
- Restore tasks back to active list
- Permanently delete individual tasks
- Clear all history with one tap

### 💾 **Cross-Platform Database**
- **Mobile (Android/iOS):** Uses `sqflite` for robust SQL database
- **Web:** Automatically switches to `sembast` (NoSQL)
- Seamless platform detection - no configuration needed
- Persistent data storage across sessions

### 🎨 **Modern UI/UX**
- Material Design 3 with dynamic color schemes
- Smooth animations and transitions
- Pull-to-refresh on all lists
- Responsive design for all screen sizes
- Intuitive gestures and interactions

---

## 📸 Screenshots

| Login Screen | Task List | History |
|--------------|-----------|---------|
| ![Login](assets/screenshots/login.png) | ![Tasks](assets/screenshots/tasks.png) | ![History](assets/screenshots/history.png) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.24.3 or higher
- Dart SDK 3.0.0 or higher
- Android Studio / VS Code with Flutter extensions
- Git

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/YOUR_USERNAME/flutter_todo_app.git
cd flutter_todo_app
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Run the app**
```bash
# On Android/iOS
flutter run

# On Web
flutter run -d chrome
```

---

## 🏗️ Project Structure

```
lib/
├── main.dart                    # App entry point & initialization
├── pages/
│   ├── login_page.dart          # Authentication UI
│   ├── home_page.dart           # Main task list view
│   └── history_page.dart        # Completed tasks view
├── models/
│   └── task.dart                # Task data model
├── database/
│   └── database_helper.dart     # Database abstraction layer
└── widgets/
    └── task_card.dart           # Reusable task card component
```

---

## 🔧 Configuration

### Android Setup

**Minimum Requirements:**
- `minSdkVersion: 21`
- `compileSdkVersion: 34`

**Permissions (AndroidManifest.xml):**
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### iOS Setup

**Minimum Requirements:**
- iOS 12.0+

**Info.plist additions** (for notifications):
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

### Web Setup

No additional configuration required! Database automatically switches to Sembast.

---

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Local Storage
  shared_preferences: ^2.2.2      # User authentication
  sqflite: ^2.3.0                 # Mobile database
  sembast: ^3.6.0                 # Web database
  sembast_web: ^2.3.0             # Web database backend
  path_provider: ^2.1.1           # File system paths
  
  # Notifications
  flutter_local_notifications: ^16.3.0
  timezone: ^0.9.2                # Timezone support
  
  # Utilities
  intl: ^0.19.0                   # Date formatting
```

---

## 🎯 How It Works

### Database Architecture

The app uses a **smart database abstraction layer** that automatically detects the platform:

```dart
Future<Database?> get database async {
  if (kIsWeb) {
    return await _initWebDatabase();  // Uses Sembast
  } else {
    return await _initMobileDatabase(); // Uses SQLite
  }
}
```

**Why?**
- SQLite (sqflite) doesn't work on web browsers
- Sembast works everywhere but SQLite is faster on mobile
- Both use the same `Task` model for consistency

### Priority System

Tasks have three priority levels with visual indicators:

- 🟢 **Low** - Green flag, for non-urgent tasks
- 🟠 **Medium** - Orange flag, default priority
- 🔴 **High** - Red flag, for urgent tasks

### Notification System

```dart
// Schedule notification
await flutterLocalNotificationsPlugin.zonedSchedule(
  taskId,
  'Task Reminder: ${task.title}',
  task.description,
  tz.TZDateTime.from(task.reminderTime!, tz.local),
  notificationDetails,
);

// Cancel on task completion
await flutterLocalNotificationsPlugin.cancel(taskId);
```

---

## 🧪 Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage

# Analyze code
flutter analyze
```

---

## 📱 Building for Production

### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Google Play)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
# Output: build/web/
```

---

## 🌐 Deployment

### GitHub Pages

1. **Build for web:**
```bash
flutter build web --base-href "/flutter_todo_app/"
```

2. **Deploy using GitHub Actions** (see `.github/workflows/deploy.yml`)

3. **Or deploy manually:**
```bash
git checkout --orphan gh-pages
cp -r build/web/* .
touch .nojekyll
git add .
git commit -m "Deploy to GitHub Pages"
git push origin gh-pages
```

Your app will be live at: `https://YOUR_USERNAME.github.io/flutter_todo_app/`

---

## 🐛 Troubleshooting

### Issue: Database not persisting
**Solution:** Make sure all database operations use `await`:
```dart
await DatabaseHelper.instance.insertTask(task);
```

### Issue: Notifications not showing (Android)
**Solution:** 
1. Check permissions in `AndroidManifest.xml`
2. For Android 13+, ensure runtime permission is granted
3. Check device battery optimization settings

### Issue: Web build fails
**Solution:**
```bash
flutter clean
flutter pub get
flutter build web --web-renderer html
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Material Design for beautiful UI components
- Open source community for excellent packages

---

## 📧 Contact

**Your Name** - [@yourhandle](https://twitter.com/yourhandle)

Project Link: [https://github.com/YOUR_USERNAME/flutter_todo_app](https://github.com/YOUR_USERNAME/flutter_todo_app)

---

## 🗺️ Roadmap

- [ ] Dark mode support
- [ ] Task categories/tags
- [ ] Cloud sync with Firebase
- [ ] Recurring tasks
- [ ] Task sharing
- [ ] Export to PDF/CSV
- [ ] Home screen widgets
- [ ] Biometric authentication
- [ ] Multi-language support
- [ ] Subtasks support

---

## ⭐ Star History

If you find this project useful, please consider giving it a star!

[![Star History Chart](https://api.star-history.com/svg?repos=YOUR_USERNAME/flutter_todo_app&type=Date)](https://star-history.com/#YOUR_USERNAME/flutter_todo_app&Date)

---

**Made with ❤️ using Flutter**