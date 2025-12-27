# Product Specification: Korean Audio Learner (Local-First)

## 1. App Overview
A standalone, offline-first Android application built with Flutter designed specifically for audio-based language learning. The app manages 60 specific audio units (approx. 30 mins each). Unlike standard music players, it prioritizes exact state restoration ("resume where I left off"), active listening controls, and bookmarking specific timestamps for review.

## 2. Technical Stack
* **Framework:** Flutter (Mobile/Android focus)
* **Language:** Dart
* **State Management:** Riverpod (Code generation preferred)
* **Local Database:** Hive (NoSQL, Key-Value pair for high performance)
* **Audio Engine:** `just_audio` (Handles playback, seeking, and asset/file loading)
* **Background Tasks:** `audio_service` (Manages notification tray, lock screen controls, and headset button events)
* **Navigation:** `go_router` or standard Navigator 2.0

## 3. Data Layer (JSON + SharedPreferences)

Instead of a heavy database, we use `shared_preferences` to store the state of each lesson.

### Storage Strategy
* **Key:** `lesson_{id}` (e.g., `lesson_1`, `lesson_60`)
* **Value:** A JSON String representing the lesson state.

### Data Structure (JSON)
```json
{
  "id": "unit_1",
  "lastPosition": 145,       // Integer (Seconds)
  "isCompleted": false,      // Boolean
  "bookmarks": [120, 400]    // List of Integers (Seconds)
}

## 4. UI/UX Specifications

### A. Home Screen (Library)
* **Layout:** A vertical scrollable list of Lesson Cards.
* **Lesson Card Component:**
    * **Left:** Unit Number (e.g., "01").
    * **Center:** Unit Title.
    * **Bottom:** Progress Bar (Visual indicator of `lastPositionSeconds / durationSeconds`).
    * **Right:** Status Icon.
        * *Empty Circle:* Not started.
        * *Yellow Play Icon:* In Progress.
        * *Green Checkmark:* Completed.
* **Interactions:**
    * Tap a card -> Navigate to **Player Screen**.
    * Long press -> Option to "Reset Progress" (clear `lastPositionSeconds` and `isCompleted`).

### B. Player Screen
* **Top Bar:** Back button (returns to Home).
* **Hero Image/Icon:** Simple placeholder or Unit Number visualization.
* **Track Info:** Large text displaying the Unit Name.
* **Progress Slider:**
    * Draggable scrubber.
    * Current time (left) and Total time (right).
* **Primary Controls (Row):**
    * **Rewind Button:** -10 seconds.
    * **Play/Pause Button:** Large, centralized FAB (Floating Action Button) style.
    * **Forward Button:** +10 seconds.
* **Secondary Controls:**
    * **Bookmark Button:** An icon button (Flag/Star).
        * *Action:* Adds current timestamp to `bookmarks` list in DB.
        * *Feedback:* Toast message "Bookmark saved at [MM:SS]".
* **Bookmarks Drawer (Bottom Sheet or Expandable List):**
    * Display a list of saved timestamps for the current lesson.
    * *Action:* Tapping a timestamp jumps the player immediately to that time.
    * *Action:* Swipe to delete a bookmark.

## 5. Functional Logic & Rules

### A. Persistence (The "Golden Rule")
* **Auto-Save:** The `lastPositionSeconds` must be saved to Hive in the following events:
    1.  User pauses the audio.
    2.  User navigates away from the Player Screen.
    3.  App goes to background/lifecycle pause.
* **Auto-Resume:** When opening a Lesson, the player must seek to `lastPositionSeconds` *before* playing. If `lastPositionSeconds > 0`, do NOT auto-play; wait for user input (prevents accidental noise).

### B. Audio Focus & Background
* **Interruption:** If a phone call comes in, audio pauses.
* **Notification:** Shows Play/Pause, Rewind, Forward buttons in the Android notification shade.
* **Lock Screen:** Must allow Play/Pause/Rewind without unlocking the phone.

### C. Progress Calculation
* Completion Threshold: 95%.
* If `currentPosition > (totalDuration * 0.95)`, update `isCompleted = true` in Hive.

### D. Asset Handling
* Since the app targets 60 specific files, the initial launch logic should:
    1.  Check if Hive Box is empty.
    2.  If empty, iterate 1 to 60.
    3.  Generate `Lesson` objects with `id: "unit_X"` and `filePath: "assets/audio/Unit_X.mp3"`.
    4.  Save initial list to Hive.

## 6. Constraints & Simplifications
* **No User Accounts:** No login screens.
* **No Cloud Sync:** Data lives and dies on the device.
* **No Speed Control:** Removed per requirements.
* **No Playlists:** User plays one Unit at a time.

## 7. Assets & File Management
* **File Location:** All audio files are stored locally in `assets/audio/`.
* **Naming Convention:** Files are strictly named `Unit_X.mp3` where X is the integer unit number (1 to 60).
    * Example: `Unit_1.mp3`, `Unit_15.mp3`, `Unit_60.mp3`.
* **Data Seeding:** On the very first app launch (when the Hive DB is empty):
    1. The app must run a loop from 1 to 60.
    2. Construct the file path string: `assets/audio/Unit_${index}.mp3`.
    3. Create a `Lesson` object for each index and save it to the Hive box. 