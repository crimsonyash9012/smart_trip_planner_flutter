# Smart Trip Planner Flutter

An AI-powered trip planning application built with Flutter that generates personalized itineraries using Groq's LLaMA model and enhances them with real-time Google Places data.

## Features

- **AI-Powered Trip Planning**: Uses Groq's LLaMA 3.3 70B model for intelligent itinerary generation
- **Live Suggestions**: Real-time hotel, restaurant, and attraction recommendations via Google Places API
- **Offline Support**: Local storage with Isar database for offline access to saved itineraries
- **Interactive Chat**: Follow-up questions and itinerary modifications through conversational AI
- **Maps Integration**: Direct route opening in Google Maps for navigation
- **Cross-Platform**: Runs on Android, iOS, Web, Windows, macOS, and Linux

## Setup

### Prerequisites

```bash
# Install Flutter (latest stable)
brew install flutter

# Install Dart (comes with Flutter)
# Verify installation
flutter doctor
```

### Firebase Configuration (Optional)

If you plan to add Firebase features:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

### Project Setup

1. **Clone and install dependencies**:
```bash
git clone <repository-url>
cd smart_trip_planner_flutter
flutter pub get
```

2. **Generate Isar database schemas**:
```bash
dart run build_runner build
```

3. **API Keys Configuration**:
   - Update `lib/core/constants.dart` with your API keys:
     - **Groq API Key**: Get from [console.groq.com](https://console.groq.com)
     - **Google Places API Key**: Get from [Google Cloud Console](https://console.cloud.google.com)

4. **Run the application**:
```bash
flutter run
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
├─────────────────────────────────────────────────────────────┤
│  HomeScreen          │  ItineraryScreen  │  TripPlannerScreen│
│  - Trip List         │  - AI Chat        │  - Simple Planning │
│  - Navigation        │  - Live Suggestions│  - Basic Interface │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                      Core Layer                             │
├─────────────────────────────────────────────────────────────┤
│  utils.dart          │  constants.dart   │  error_utils.dart │
│  - JSON Processing   │  - API Keys       │  - Error Handling │
│  - Location Utils    │  - System Prompt  │  - Connectivity   │
│  - Map Integration   │  - Model Config   │  - Timeout Mgmt   │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                             │
├─────────────────────────────────────────────────────────────┤
│  Isar Database       │  HTTP Client      │  Model Classes    │
│  - Local Storage     │  - API Requests   │  - Itinerary      │
│  - Offline Access    │  - Response Parse │  - JSON Schema    │
│  - CRUD Operations   │  - Error Handling │  - Serialization  │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                   External Services                         │
├─────────────────────────────────────────────────────────────┤
│  Groq API           │  Google Places API │  Maps Integration │
│  - LLaMA 3.3 70B    │  - Text Search     │  - Route Opening  │
│  - Chat Completion  │  - Place Details   │  - Web Browser    │
│  - JSON Generation  │  - Live Suggestions│  - Cross-Platform │
└─────────────────────────────────────────────────────────────┘
```

## Agent Chain Workflow

### 1. Prompt Engineering
The system uses a structured prompt in `constants.dart` that enforces:
- **Strict JSON output** with predefined schema
- **Location format**: All coordinates in "lat,lng" format
- **Budget constraints**: Realistic INR estimates
- **Required fields**: Ensures complete itinerary structure

### 2. Tools Integration

#### Primary Tools:
- **Groq LLaMA 3.3 70B**: Main reasoning and planning engine
- **Google Places Text Search**: Real-world data validation
- **Isar Database**: Local persistence and offline access

#### Tool Chain Flow:
```
User Input → Groq API → JSON Validation → Live Enhancement → Storage
     ↓           ↓            ↓               ↓            ↓
  Prompt    LLaMA Model   Schema Check   Google Places   Isar DB
```

### 3. Validation Pipeline

#### JSON Schema Validation:
```dart
// Required structure enforced by system prompt
{
  "title": "string",
  "startDate": "YYYY-MM-DD",
  "endDate": "YYYY-MM-DD", 
  "days": [...],
  "hotels": [...],
  "touristSpots": [...],
  "food": [...],
  "transportOptions": [...],
  "estimatedBudget": {...}
}
```

#### Error Recovery:
- **JSON Repair**: Automatic fixing of malformed JSON
- **Fallback Parsing**: Graceful degradation for partial responses
- **Retry Logic**: Timeout and connectivity error handling

#### Live Enhancement:
- **Google Places Integration**: Real-time validation of suggestions
- **Groq Ranking**: AI-powered selection of best options from search results
- **Quality Scoring**: Rating and review-based recommendation ranking

## Token Cost Analysis

Based on testing with various trip scenarios:

| Operation | Model | Avg Input Tokens | Avg Output Tokens | Cost per Request* | Use Case |
|-----------|-------|------------------|-------------------|-------------------|----------|
| **Initial Trip Generation** | LLaMA 3.3 70B | 450-600 | 800-1200 | $0.0008-0.0012 | New itinerary creation |
| **Follow-up Modifications** | LLaMA 3.3 70B | 800-1500 | 400-800 | $0.0010-0.0018 | Itinerary updates |
| **Live Suggestion Ranking** | LLaMA 3.3 70B | 200-350 | 100-150 | $0.0002-0.0004 | Google Places ranking |
| **JSON Repair Operations** | LLaMA 3.3 70B | 300-500 | 200-400 | $0.0003-0.0006 | Error recovery |

### Cost Breakdown by Trip Complexity:

| Trip Type | Total Tokens | Estimated Cost* | Operations |
|-----------|--------------|-----------------|------------|
| **Simple (2-3 days, domestic)** | 1,200-1,800 | $0.0012-0.0018 | 1 generation + 2-3 enhancements |
| **Medium (4-7 days, domestic)** | 2,000-3,500 | $0.0020-0.0035 | 1 generation + 4-6 enhancements |
| **Complex (7+ days, international)** | 3,500-5,000 | $0.0035-0.0050 | 1 generation + 6-8 enhancements |
| **With Follow-ups (3-5 modifications)** | +1,500-2,500 | +$0.0015-0.0025 | Additional conversation turns |

### Monthly Usage Estimates:

| User Type | Trips/Month | Avg Cost/Trip | Monthly Cost* |
|-----------|-------------|---------------|---------------|
| **Light User** | 2-3 trips | $0.002 | $0.004-0.006 |
| **Regular User** | 5-8 trips | $0.003 | $0.015-0.024 |
| **Heavy User** | 10-15 trips | $0.003 | $0.030-0.045 |

*_Costs based on Groq's pricing: $0.59/1M input tokens, $0.79/1M output tokens (as of 2024)_

### Optimization Strategies:
- **Conversation Context**: Maintains chat history for better follow-ups
- **JSON Schema Enforcement**: Reduces need for repair operations  
- **Caching**: Local storage prevents re-generation of similar requests
- **Batch Processing**: Live suggestions processed in parallel

## Dependencies

### Core Dependencies:
```yaml
flutter_riverpod: ^2.6.1      # State management
isar: ^3.1.0+1                # Local database
http: ^1.5.0                  # API requests
connectivity_plus: ^6.1.0     # Network status
```

### UI Dependencies:
```yaml
flutter_markdown_plus: ^1.0.3 # Markdown rendering
url_launcher: ^6.3.2          # External links
cupertino_icons: ^1.0.8       # iOS-style icons
```

### Development Dependencies:
```yaml
build_runner: ^2.4.6          # Code generation
isar_generator: ^3.1.0+1      # Database schema generation
json_serializable: ^6.6.2     # JSON serialization
flutter_lints: ^5.0.0         # Code quality
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Video Link

https://drive.google.com/drive/folders/1Kd51GB-B8mKUZtgolCzKL_Ase_abjwZZ?usp=sharing

## Support

For support and questions:
- Create an issue in the repository
- Check the [Flutter documentation](https://docs.flutter.dev/)
- Review [Groq API documentation](https://console.groq.com/docs)
- Consult [Google Places API documentation](https://developers.google.com/maps/documentation/places/web-service)
