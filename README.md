# SleepTrack

## Features

- ✅ Display the current app version
- ✅ Automatic check for updates from GitHub
- ✅ Download and install new APKs
- ✅ Modern UI with Material Design 3
- ✅ Download progress bar
- ✅ Error handling and loading states

## Configuration

### 1. Modify GitHub variables

In the `lib/update_service.dart` file, change the following variables with your data:

```dart
_githubOwner = 'your-username';   // Your GitHub username
_githubRepo = 'release_test';    // The name of your repository
```

### 2. Create a Release on GitHub

1. Go to your GitHub repository
2. Click on "Releases" in the sidebar
3. Click "Create a new release"
4. Enter a tag (e.g., `v1.0.1`)
5. Add a description for the release
6. **Important**: Upload the APK file in the "Attachments" section
7. Publish the release

### 3. Build the APK

To create an APK for distribution:

```bash
flutter build apk --release
```

The APK will be available at: `build/app/outputs/flutter-apk/app-release.apk`

## How it works

1.  **Version Check**: The app compares the current version with the latest release on GitHub
2.  **Download**: If a newer version is available, the app downloads the APK
3.  **Installation**: The app opens the Android installer to install the new APK

## Required Permissions

The app requires the following Android permissions:
- `INTERNET`: To download updates
- `REQUEST_INSTALL_PACKAGES`: To install new APKs

## Dependencies

- `package_info_plus`: To get the app version
- `http`: For HTTP requests
- `path_provider`: To manage file paths
- `permission_handler`: To handle Android permissions
- `open_file`: To open the downloaded APK for installation

## Important Notes

### For private repositories
If your repository is private, you will need to:
1. Create a Personal Access Token on GitHub with `repo` scope.
2. The app is not currently configured to handle private repositories, you would need to modify the code to include the token in the request headers.

### Versioning
- Use semantic versioning (e.g., `1.0.0`, `1.0.1`, `1.1.0`)
- The GitHub tag must match the version in `pubspec.yaml`
- For releases, use the `v` prefix (e.g., `v1.0.1`)

### Security
- Always verify the integrity of downloaded APKs
- Consider implementing digital signatures for APKs
- Always test updates before distribution

## Troubleshooting

### Error "APK not found in release"
Make sure you have uploaded an `.apk` file to the GitHub release.

### Error "Storage permissions not granted"
The user must grant storage permissions when requested by the app.

### Error "Error opening APK file"
On some Android devices, it may be necessary to enable installation from unknown sources in the settings.

## Development

To run the app in development mode:

```bash
flutter run
```

For debug builds:

```bash
flutter build apk --debug
```

## License

This project is released under the MIT license.
