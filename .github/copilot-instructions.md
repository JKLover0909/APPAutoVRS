# Copilot Instructions for AutoVRS Flutter App

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## Project Overview
This is a Flutter application for AutoVRS (Automatic Visual Recognition System) - a machine vision inspection system for electronic components manufacturing.

## Key Requirements
- **Language**: Vietnamese (vi-VN) localization
- **Architecture**: Clean architecture with proper state management
- **UI**: Material Design 3 with custom industrial theme
- **Navigation**: Sidebar navigation with view history and back functionality
- **Authentication**: Password-protected sections for different user roles (admin, worker)
- **Image Processing**: Support for camera feeds, design files, and alignment operations
- **Charts**: Statistics visualization with pie charts and data tables
- **Responsive Design**: Support for different screen sizes

## Key Features to Implement
1. **Dashboard/Home View**: System status overview
2. **Model Management**: Add/select manufacturing models
3. **Auto VRS Monitoring**: Real-time inspection monitoring
4. **Manual VRS**: Manual inspection with image comparison
5. **Statistics**: Defect analysis with charts and reports
6. **Board Alignment**: 4-step alignment process with image interaction
7. **Light Adjustment**: Camera lighting controls

## Technical Stack
- **State Management**: Provider or Riverpod
- **Charts**: fl_chart for statistics visualization
- **Images**: cached_network_image for efficient image loading
- **Navigation**: GoRouter for declarative navigation
- **Storage**: SharedPreferences for settings and Hive for local data
- **Internationalization**: flutter_localizations with Vietnamese support

## Code Style Guidelines
- Use meaningful Vietnamese variable/method names where appropriate
- Follow Flutter best practices and Material Design guidelines
- Implement proper error handling and loading states
- Use const constructors where possible for performance
- Organize code with proper separation of concerns (models, views, controllers)
