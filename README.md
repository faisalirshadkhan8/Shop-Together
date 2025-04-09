# Shop-Together

This is a Flutter-based shopping list application that allows users to manage their shopping items efficiently. The app integrates with Firebase Firestore for real-time data synchronization and supports offline functionality for seamless user experience.

## Features

- **Data Consistency**: Uses Firestore transactions to prevent conflicting updates when multiple users modify the same item simultaneously.
- **Offline Support**: Enables users to add or update items without an internet connection, with automatic synchronization when reconnected.
- **Real-Time Updates**: Reflects changes instantly across all connected devices using Firestore's real-time capabilities.
- **Error Handling**: Provides user-friendly error messages for network issues and Firestore permission errors.
- **Responsive UI**: Designed with Material Design principles for a clean and intuitive user interface.

## Technologies Used

- **Flutter**: For building the cross-platform mobile application.
- **Firebase Firestore**: For real-time database and offline persistence.
- **Connectivity Plus**: For monitoring network connectivity.
- **Dart**: The programming language used for Flutter development.

## Getting Started

1. Clone the repository.
2. Run `flutter pub get` to install dependencies.
3. Configure Firebase for your platform using the `firebase_options.dart` file.
4. Run the app using `flutter run`.

## License

This project is licensed under the MIT License.
