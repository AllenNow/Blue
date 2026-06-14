# Picture Viewer Architecture Document

## Introduction

### Starter Template

This architecture document defines the technical design for the Picture Viewer feature in the Live Chat Flutter SDK. The feature enables users to view, zoom, pan, and save images from chat messages in a full-screen immersive experience.

**Related Documents**:
- PRD: `PRD-picture-viewer.md`
- Issue: WISE2018-34808

**Key Objectives**:
- Provide professional full-screen image viewing experience
- Support intuitive gestures (pinch zoom, double-tap, pan, swipe)
- Enable image saving to device gallery
- Support multi-image browsing with smooth transitions
- Maintain high performance and low memory footprint

### Change Log

| Date | Version | Description | Author |
| :--- | :------ | :---------- | :----- |
| 2026-03-05 | 0.1 | Initial architecture draft | allen (AI-assisted) |

---

## High Level Architecture

### Technical Summary

The Picture Viewer feature is implemented as a standalone full-screen page that integrates with the existing chat message system. It uses the **extended_image** package for advanced image rendering and gesture handling, following Flutter's MVVM pattern with GetX for state management.

**Core Technologies**:
- **extended_image** (v8.2.0): Image display, zoom, pan, and gesture handling
- **image_gallery_saver** (v2.0.3): Save images to device gallery
- **permission_handler** (v11.0.1): Runtime permission management
- **GetX**: State management and navigation

**Architecture Pattern**: MVVM (Model-View-ViewModel)


### High Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Chat Interface                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ImageMessageBubble (Thumbnail)                          │  │
│  │    - CachedNetworkImage                                  │  │
│  │    - Hero tag: 'image_${messageId}'                      │  │
│  │    - onTap() → Navigate to ImageViewerPage               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ (User taps image)
                    Navigator.push() with Hero animation
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    ImageViewerPage (Full Screen)                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  ImageViewerController (GetX)                            │  │
│  │    - currentIndex: RxInt                                 │  │
│  │    - images: List<ImageViewerItem>                       │  │
│  │    - isLoading: RxBool                                   │  │
│  │    - saveImage(), shareImage(), rotateImage()            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  UI Layer                                                │  │
│  │  ├─ ImageViewerTopBar (Close button, counter)           │  │
│  │  ├─ ExtendedImageGesturePageView (Multi-image)          │  │
│  │  │    └─ ExtendedImage.network (Single image)           │  │
│  │  │         - Gesture handling (zoom, pan)               │  │
│  │  │         - Hero animation                              │  │
│  │  │         - Loading indicator                           │  │
│  │  └─ ImageViewerBottomBar (Save, share, rotate)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ↓                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Services Layer                                          │  │
│  │  ├─ ImageSaveService                                     │  │
│  │  │    - checkPermission()                                │  │
│  │  │    - downloadImage()                                  │  │
│  │  │    - saveToGallery()                                  │  │
│  │  └─ SdkFileCacheService (existing)                       │  │
│  │       - getCachedFile()                                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### System Context

The Picture Viewer integrates with existing SDK components:

1. **Chat Message System**: Receives image messages from `SdkChatDetailController`
2. **File Cache System**: Uses `SdkFileCacheService` for image caching
3. **Navigation System**: Uses Flutter Navigator with Hero animations
4. **Permission System**: Manages device permissions for gallery access

**Data Flow**:
```
User taps image → ImageMessageBubble.onTap()
                → Get all image messages from current chat
                → Find current image index
                → Navigator.push(ImageViewerPage)
                → Load images with ExtendedImage
                → User interacts (zoom, pan, swipe)
                → User saves image
                → Request permission
                → Download image
                → Save to gallery
                → Show success/error feedback
```

---

## Architecture Decision Records (ADRs)

### ADR-001: Use extended_image for Image Rendering and Gestures

**Status**: ✅ Accepted  
**Date**: 2026-03-05  
**Decision Makers**: allen (AI-assisted)

**Context**:
We need a robust solution for displaying images with zoom, pan, and gesture support. Flutter's built-in Image widget lacks advanced gesture handling. We evaluated 5 packages:
- photo_view: Basic zoom/pan, limited features
- extended_image: Comprehensive features, excellent performance
- flutter_image_viewer: Simple but limited
- pinch_zoom: Basic zoom only
- easy_image_viewer: Quick setup but less customizable

**Decision**:
Use **extended_image** (v8.2.0) as the core image rendering library.

**Rationale**:
1. **Comprehensive Features**: Supports zoom, pan, rotation, crop, gesture handling, loading states, error handling
2. **Performance**: Optimized for large images, efficient memory management, smooth 60fps animations
3. **Active Maintenance**: 2.5k+ stars, regular updates, responsive maintainer
4. **Multi-image Support**: Built-in ExtendedImageGesturePageView for gallery browsing
5. **Customization**: Highly configurable gesture parameters, loading/error widgets
6. **Production Ready**: Used by many production apps, proven stability

**Consequences**:
- ✅ Reduced development time (no custom gesture implementation)
- ✅ Better performance than custom solution
- ✅ Active community support
- ⚠️ Dependency on third-party package (mitigated by package maturity)
- ⚠️ Package size ~200KB (acceptable for features provided)

**Alternatives Considered**:
- Custom implementation: Too time-consuming, reinventing the wheel
- photo_view: Missing features like rotation, crop, advanced gestures
- Multiple packages: Increased complexity and potential conflicts

---

### ADR-002: Implement Hero Animation for Image Transitions

**Status**: ✅ Accepted  
**Date**: 2026-03-05  
**Decision Makers**: allen (AI-assisted)

**Context**:
Users need visual continuity when transitioning from thumbnail to full-screen view. Abrupt transitions feel jarring and unprofessional. We need to decide on the transition animation approach.

**Decision**:
Use Flutter's **Hero widget** for seamless thumbnail-to-fullscreen transitions.

**Rationale**:
1. **Native Flutter Support**: Built-in widget, no additional dependencies
2. **Smooth Animation**: Automatic interpolation between thumbnail and full-screen positions
3. **Platform Consistency**: Follows iOS and Android design guidelines
4. **Simple Implementation**: Just wrap images with Hero widget using matching tags
5. **Performance**: Hardware-accelerated, 60fps animations
6. **User Expectation**: Standard pattern in modern mobile apps (Instagram, Twitter, etc.)

**Implementation Details**:
```dart
// Thumbnail in chat
Hero(
  tag: 'image_${message.uniqueId}',
  child: CachedNetworkImage(imageUrl: thumbnailUrl),
)

// Full-screen viewer
Hero(
  tag: 'image_${message.uniqueId}',
  child: ExtendedImage.network(fullImageUrl),
)
```

**Consequences**:
- ✅ Professional, polished user experience
- ✅ Visual continuity reduces cognitive load
- ✅ Zero additional dependencies
- ✅ Automatic animation handling
- ⚠️ Requires unique tags for each image (easily managed with message IDs)

**Alternatives Considered**:
- Fade transition: Less engaging, no spatial continuity
- Custom animation: More complex, no significant benefit
- No animation: Poor user experience

---

### ADR-003: Use MVVM Pattern with GetX for State Management

**Status**: ✅ Accepted  
**Date**: 2026-03-05  
**Decision Makers**: allen (AI-assisted)

**Context**:
The Picture Viewer needs to manage state for current image index, loading states, error states, and user actions. The SDK already uses GetX for state management in other features. We need consistent architecture.

**Decision**:
Implement **MVVM pattern** with **GetX** for state management.

**Rationale**:
1. **Consistency**: Matches existing SDK architecture (SdkChatDetailController uses GetX)
2. **Reactive UI**: Automatic UI updates when state changes (Obx, Rx variables)
3. **Separation of Concerns**: Clear separation between UI (View) and business logic (Controller)
4. **Testability**: Controllers can be unit tested independently
5. **Minimal Boilerplate**: GetX reduces boilerplate compared to Provider or Bloc
6. **Performance**: Efficient reactive updates, only rebuilds affected widgets

**Architecture**:
```
Model (ImageViewerItem)
  ↓
ViewModel (ImageViewerController)
  - State: currentIndex, images, isLoading, error
  - Actions: saveImage(), shareImage(), rotateImage()
  ↓
View (ImageViewerPage)
  - Observes controller state with Obx()
  - Triggers controller actions on user input
```

**Consequences**:
- ✅ Consistent with existing SDK patterns
- ✅ Easy to test business logic
- ✅ Clean separation of concerns
- ✅ Reactive UI updates
- ⚠️ Team must understand GetX patterns (already familiar)

**Alternatives Considered**:
- StatefulWidget: Harder to test, mixes UI and logic
- Provider: More boilerplate, inconsistent with SDK
- Bloc: Too heavy for this feature's complexity

---

### ADR-004: Implement Permission Handling with Graceful Degradation

**Status**: ✅ Accepted  
**Date**: 2026-03-05  
**Decision Makers**: allen (AI-assisted)

**Context**:
Saving images requires gallery/photos permission on iOS and Android. Users may deny permission, and we need to handle this gracefully without breaking the app or frustrating users.

**Decision**:
Use **permission_handler** package with **graceful degradation** strategy.

**Rationale**:
1. **Cross-Platform**: Single API for iOS and Android permissions
2. **Comprehensive**: Handles request, check, and settings navigation
3. **User-Friendly**: Provide clear explanations and fallback options
4. **Non-Blocking**: Permission denial doesn't break other features

**Permission Flow**:
```
User taps "Save" button
  ↓
Check current permission status
  ↓
├─ Granted → Download and save image
├─ Denied → Show explanation dialog
│            ├─ "Open Settings" button
│            └─ "Copy Link" fallback option
├─ Permanently Denied → Show settings dialog
└─ Not Determined → Request permission
                     └─ Handle result (granted/denied)
```

**User Experience**:
1. **First Request**: Show clear explanation before requesting
2. **Denied**: Offer to open settings + provide fallback (copy link)
3. **Permanently Denied**: Direct to settings with instructions
4. **Granted**: Save image and show success toast

**Consequences**:
- ✅ Respects user privacy choices
- ✅ Provides fallback options
- ✅ Clear user communication
- ✅ Doesn't block other features
- ⚠️ Requires platform-specific permission configuration (standard practice)

**Alternatives Considered**:
- No fallback: Poor UX when permission denied
- Manual permission handling: Platform-specific code, more complex
- Ignore permissions: App store rejection risk


---

## Component Design

### 1. Data Models

#### ImageViewerItem

**Purpose**: Encapsulates image data for the viewer

**Properties**:
```dart
class ImageViewerItem {
  final String imageUrl;        // Full-size image URL
  final String? thumbnailUrl;   // Optional thumbnail for progressive loading
  final String messageId;       // Unique message identifier
  final int? width;             // Image width (if available)
  final int? height;            // Image height (if available)
  final DateTime timestamp;     // Message timestamp
  final String? senderName;     // Sender name (for display)
  
  ImageViewerItem({
    required this.imageUrl,
    this.thumbnailUrl,
    required this.messageId,
    this.width,
    this.height,
    required this.timestamp,
    this.senderName,
  });
  
  // Factory constructor from SdkMessage
  factory ImageViewerItem.fromMessage(SdkMessage message) {
    final content = message.content as ImageMessageContent;
    return ImageViewerItem(
      imageUrl: content.imageUrl,
      thumbnailUrl: content.thumbnailUrl,
      messageId: message.uniqueId,
      width: content.imageWidth,
      height: content.imageHeight,
      timestamp: message.timestamp,
      senderName: message.senderName,
    );
  }
}
```

**Responsibilities**:
- Store image metadata
- Convert from SdkMessage to viewer format
- Provide data for UI rendering

---

### 2. Controllers

#### ImageViewerController

**Purpose**: Manages state and business logic for image viewer

**State Properties**:
```dart
class ImageViewerController extends GetxController {
  // Observable state
  final RxList<ImageViewerItem> images = <ImageViewerItem>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxString error = ''.obs;
  final RxBool showToolbar = true.obs;
  
  // Services
  final ImageSaveService _saveService = Get.find();
  final SdkFileCacheService _cacheService = Get.find();
  
  // Page controller for multi-image browsing
  late PageController pageController;
}
```

**Key Methods**:
```dart
// Initialize with image list and starting index
void init(List<ImageViewerItem> images, int initialIndex);

// Navigation
void nextImage();
void previousImage();
void jumpToImage(int index);

// Actions
Future<void> saveImage();
Future<void> shareImage();
void rotateImage();
void toggleToolbar();

// Lifecycle
@override
void onInit();

@override
void onClose();
```

**Responsibilities**:
- Manage current image index
- Handle user actions (save, share, rotate)
- Coordinate with services
- Provide reactive state to UI
- Manage page controller lifecycle

---

### 3. Views

#### ImageViewerPage

**Purpose**: Full-screen image viewer page

**Structure**:
```dart
class ImageViewerPage extends StatelessWidget {
  final List<ImageViewerItem> images;
  final int initialIndex;
  
  @override
  Widget build(BuildContext context) {
    return GetBuilder<ImageViewerController>(
      init: ImageViewerController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Main image viewer
              _buildImageViewer(controller),
              
              // Top bar (close button, counter)
              Obx(() => controller.showToolbar.value
                ? ImageViewerTopBar()
                : SizedBox.shrink()),
              
              // Bottom toolbar (save, share, etc.)
              Obx(() => controller.showToolbar.value
                ? ImageViewerBottomBar()
                : SizedBox.shrink()),
              
              // Loading overlay
              Obx(() => controller.isLoading.value
                ? _buildLoadingOverlay()
                : SizedBox.shrink()),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildImageViewer(ImageViewerController controller) {
    return ExtendedImageGesturePageView.builder(
      controller: controller.pageController,
      itemCount: images.length,
      onPageChanged: (index) => controller.currentIndex.value = index,
      itemBuilder: (context, index) {
        return _buildImageItem(images[index]);
      },
    );
  }
  
  Widget _buildImageItem(ImageViewerItem item) {
    return Hero(
      tag: 'image_${item.messageId}',
      child: ExtendedImage.network(
        item.imageUrl,
        mode: ExtendedImageMode.gesture,
        initGestureConfigHandler: _gestureConfig,
        loadStateChanged: _loadStateChanged,
        onDoubleTap: _handleDoubleTap,
      ),
    );
  }
}
```

**Responsibilities**:
- Render full-screen image viewer
- Handle user gestures
- Display loading and error states
- Coordinate with controller

---

#### ImageViewerTopBar

**Purpose**: Top toolbar with close button and image counter

**Structure**:
```dart
class ImageViewerTopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ImageViewerController>();
    
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close button
            IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            
            // Image counter
            Obx(() => Text(
              '${controller.currentIndex.value + 1}/${controller.images.length}',
              style: TextStyle(color: Colors.white, fontSize: 16),
            )),
          ],
        ),
      ),
    );
  }
}
```

**Responsibilities**:
- Display close button
- Show current image position
- Handle close action

---

#### ImageViewerBottomBar

**Purpose**: Bottom toolbar with action buttons

**Structure**:
```dart
class ImageViewerBottomBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ImageViewerController>();
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Save button
            _buildActionButton(
              icon: Icons.download,
              label: 'Save',
              onPressed: controller.saveImage,
            ),
            
            // Share button (Phase 2)
            _buildActionButton(
              icon: Icons.share,
              label: 'Share',
              onPressed: controller.shareImage,
            ),
            
            // Rotate button (Phase 2)
            _buildActionButton(
              icon: Icons.rotate_right,
              label: 'Rotate',
              onPressed: controller.rotateImage,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Responsibilities**:
- Display action buttons
- Trigger controller actions
- Show loading states on buttons

---

### 4. Services

#### ImageSaveService

**Purpose**: Handle image downloading and saving to gallery

**Methods**:
```dart
class ImageSaveService {
  final PermissionHandler _permissionHandler = PermissionHandler();
  
  /// Check if gallery permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }
  
  /// Request gallery permission
  Future<PermissionStatus> requestPermission() async {
    return await Permission.photos.request();
  }
  
  /// Download image from URL
  Future<Uint8List> downloadImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to download image: ${response.statusCode}');
  }
  
  /// Save image to gallery
  Future<bool> saveToGallery(Uint8List imageBytes, {String? name}) async {
    try {
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: name ?? 'image_${DateTime.now().millisecondsSinceEpoch}',
      );
      return result['isSuccess'] == true;
    } catch (e) {
      print('Error saving image: $e');
      return false;
    }
  }
  
  /// Complete save flow with permission handling
  Future<SaveImageResult> saveImage(String imageUrl) async {
    try {
      // 1. Check permission
      if (!await hasPermission()) {
        final status = await requestPermission();
        if (!status.isGranted) {
          return SaveImageResult.permissionDenied();
        }
      }
      
      // 2. Download image
      final imageBytes = await downloadImage(imageUrl);
      
      // 3. Save to gallery
      final success = await saveToGallery(imageBytes);
      
      return success
        ? SaveImageResult.success()
        : SaveImageResult.failed('Failed to save image');
        
    } catch (e) {
      return SaveImageResult.failed(e.toString());
    }
  }
}

// Result class
class SaveImageResult {
  final bool success;
  final String? error;
  final bool permissionDenied;
  
  SaveImageResult.success() : success = true, error = null, permissionDenied = false;
  SaveImageResult.failed(this.error) : success = false, permissionDenied = false;
  SaveImageResult.permissionDenied() : success = false, error = null, permissionDenied = true;
}
```

**Responsibilities**:
- Manage gallery permissions
- Download images from URLs
- Save images to device gallery
- Handle errors gracefully


---

## Data Flow

### 1. Opening Image Viewer

```
User Action: Tap image in chat
  ↓
ImageMessageBubble.onTap()
  ↓
Get SdkChatDetailController
  ↓
Extract all image messages from current chat
  messages.where((m) => m.type == SdkMessageType.image)
  ↓
Convert to List<ImageViewerItem>
  ImageViewerItem.fromMessage(message)
  ↓
Find current image index
  images.indexWhere((item) => item.messageId == currentMessageId)
  ↓
Navigator.push(
  MaterialPageRoute(
    builder: (_) => ImageViewerPage(
      images: images,
      initialIndex: currentIndex,
    ),
  ),
)
  ↓
Hero animation: thumbnail → full-screen
  ↓
ImageViewerPage rendered
  ↓
ImageViewerController.init(images, initialIndex)
  ↓
ExtendedImage starts loading full-size image
  ↓
Show loading indicator
  ↓
Image loaded → Display with gesture support
```

---

### 2. Browsing Multiple Images

```
User Action: Swipe left/right
  ↓
ExtendedImageGesturePageView detects swipe
  ↓
PageController animates to next/previous page
  ↓
onPageChanged(newIndex) callback
  ↓
controller.currentIndex.value = newIndex
  ↓
Obx() widgets react to state change
  ↓
Update image counter: "2/10" → "3/10"
  ↓
Load new image if not cached
  ↓
Display new image with gesture support
```

---

### 3. Saving Image

```
User Action: Tap "Save" button
  ↓
controller.saveImage()
  ↓
Set isSaving.value = true (show loading)
  ↓
Get current image: images[currentIndex.value]
  ↓
Call ImageSaveService.saveImage(imageUrl)
  ↓
ImageSaveService.hasPermission()
  ↓
├─ Permission Granted
│   ↓
│   downloadImage(url)
│   ↓
│   HTTP GET request
│   ↓
│   Receive image bytes
│   ↓
│   saveToGallery(bytes)
│   ↓
│   ImageGallerySaver.saveImage()
│   ↓
│   Return SaveImageResult.success()
│   ↓
│   Show success toast: "Image saved"
│   ↓
│   Set isSaving.value = false
│
└─ Permission Denied
    ↓
    requestPermission()
    ↓
    Show system permission dialog
    ↓
    ├─ User grants permission
    │   ↓
    │   Retry save flow
    │
    └─ User denies permission
        ↓
        Return SaveImageResult.permissionDenied()
        ↓
        Show dialog:
        "Gallery permission required to save images"
        [Open Settings] [Copy Link] [Cancel]
        ↓
        Set isSaving.value = false
```

---

### 4. Gesture Handling

```
User Action: Pinch to zoom
  ↓
ExtendedImage gesture detector
  ↓
Calculate scale factor (0.5x - 3.0x)
  ↓
Update image transform matrix
  ↓
Render scaled image (60fps)
  ↓
User releases fingers
  ↓
Apply inertial animation if needed
  ↓
Clamp to min/max scale bounds
```

```
User Action: Double tap
  ↓
ExtendedImage onDoubleTap callback
  ↓
Check current scale
  ↓
├─ scale == 1.0
│   ↓
│   Animate to 2.0x (200ms)
│   Center on tap position
│
└─ scale != 1.0
    ↓
    Animate to 1.0x (200ms)
    Reset to center
```

```
User Action: Pan (when zoomed)
  ↓
ExtendedImage gesture detector
  ↓
Calculate new offset
  ↓
Check boundaries
  ↓
Clamp to image bounds
  ↓
Update image position
  ↓
Render at new position (60fps)
```

---

### 5. Closing Viewer

```
User Action: Tap close button / background / back button
  ↓
Navigator.pop()
  ↓
Hero animation: full-screen → thumbnail
  ↓
ImageViewerController.onClose()
  ↓
Dispose PageController
  ↓
Clear state
  ↓
Return to chat page
  ↓
Thumbnail visible in chat
```

---

## API Design

### Navigation API

```dart
/// Open image viewer from chat
static Future<void> openImageViewer({
  required BuildContext context,
  required List<SdkMessage> messages,
  required String currentMessageId,
}) async {
  // Filter image messages
  final imageMessages = messages
    .where((m) => m.type == SdkMessageType.image)
    .toList();
  
  if (imageMessages.isEmpty) return;
  
  // Convert to viewer items
  final images = imageMessages
    .map((m) => ImageViewerItem.fromMessage(m))
    .toList();
  
  // Find current index
  final currentIndex = images.indexWhere(
    (item) => item.messageId == currentMessageId,
  );
  
  if (currentIndex == -1) return;
  
  // Navigate
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ImageViewerPage(
        images: images,
        initialIndex: currentIndex,
      ),
    ),
  );
}
```

---

### Controller API

```dart
class ImageViewerController extends GetxController {
  /// Initialize controller with images and starting index
  void init(List<ImageViewerItem> images, int initialIndex) {
    this.images.value = images;
    this.currentIndex.value = initialIndex;
    pageController = PageController(initialPage: initialIndex);
  }
  
  /// Navigate to next image
  void nextImage() {
    if (currentIndex.value < images.length - 1) {
      pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  /// Navigate to previous image
  void previousImage() {
    if (currentIndex.value > 0) {
      pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  /// Save current image to gallery
  Future<void> saveImage() async {
    if (isSaving.value) return;
    
    isSaving.value = true;
    error.value = '';
    
    try {
      final currentImage = images[currentIndex.value];
      final saveService = Get.find<ImageSaveService>();
      final result = await saveService.saveImage(currentImage.imageUrl);
      
      if (result.success) {
        Get.snackbar(
          'Success',
          'Image saved to gallery',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else if (result.permissionDenied) {
        _showPermissionDialog();
      } else {
        throw Exception(result.error ?? 'Failed to save image');
      }
    } catch (e) {
      error.value = e.toString();
      Get.snackbar(
        'Error',
        'Failed to save image: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSaving.value = false;
    }
  }
  
  /// Toggle toolbar visibility
  void toggleToolbar() {
    showToolbar.value = !showToolbar.value;
  }
}
```

---

### Service API

```dart
class ImageSaveService {
  /// Save image with full permission handling
  Future<SaveImageResult> saveImage(String imageUrl);
  
  /// Check if permission is granted
  Future<bool> hasPermission();
  
  /// Request permission
  Future<PermissionStatus> requestPermission();
  
  /// Download image from URL
  Future<Uint8List> downloadImage(String url);
  
  /// Save image bytes to gallery
  Future<bool> saveToGallery(Uint8List imageBytes, {String? name});
}
```

---

## Performance Considerations

### 1. Memory Management

**Challenge**: Loading multiple high-resolution images can consume significant memory.

**Solutions**:
- **Image Caching**: Use extended_image's built-in cache with size limits
  ```dart
  ExtendedImage.network(
    url,
    cache: true,
    cacheWidth: 1080, // Limit cached image width
    cacheHeight: 1920, // Limit cached image height
  )
  ```
- **Lazy Loading**: Only load visible and adjacent images
- **Cache Eviction**: Clear cache when memory warning received
- **Dispose Resources**: Properly dispose controllers and listeners

**Metrics**:
- Target: < 50MB memory increase
- Monitor: Use Flutter DevTools memory profiler
- Alert: If memory > 100MB, investigate leaks

---

### 2. Image Loading Speed

**Challenge**: Large images take time to download and decode.

**Solutions**:
- **Progressive Loading**: Show thumbnail first, then full-size
  ```dart
  ExtendedImage.network(
    fullImageUrl,
    loadStateChanged: (state) {
      if (state.extendedImageLoadState == LoadState.loading) {
        return Image.network(thumbnailUrl); // Show thumbnail
      }
      return null;
    },
  )
  ```
- **Preloading**: Preload adjacent images in background
- **HTTP/2**: Use HTTP/2 for faster downloads (automatic with http package)
- **Image Compression**: Request appropriately sized images from server

**Metrics**:
- Target: < 2s load time for 1MB image on 4G
- Monitor: Track load times in analytics
- Alert: If > 5s, investigate network or server issues

---

### 3. Gesture Performance

**Challenge**: Smooth 60fps gestures during zoom and pan.

**Solutions**:
- **Hardware Acceleration**: extended_image uses GPU acceleration
- **Efficient Rendering**: Only redraw affected areas
- **Debouncing**: Limit gesture update frequency if needed
- **Optimized Transforms**: Use matrix transforms (GPU-accelerated)

**Metrics**:
- Target: ≥ 30 FPS during gestures (ideally 60 FPS)
- Monitor: Use Flutter Performance overlay
- Alert: If FPS < 30, profile and optimize

---

### 4. Battery Consumption

**Challenge**: Image processing and rendering can drain battery.

**Solutions**:
- **Efficient Decoding**: Use platform-native image decoders
- **Minimize Redraws**: Only update when necessary
- **Background Throttling**: Pause operations when app backgrounded
- **Optimize Animations**: Use efficient animation curves

**Metrics**:
- Target: < 5% battery drain per 10 minutes of use
- Monitor: Test on real devices
- Alert: If > 10%, investigate power-hungry operations


---

## Security Considerations

### 1. Image URL Validation

**Risk**: Malicious URLs could lead to security vulnerabilities.

**Mitigation**:
```dart
bool isValidImageUrl(String url) {
  // Only allow HTTPS URLs
  if (!url.startsWith('https://')) {
    return false;
  }
  
  // Validate URL format
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) {
    return false;
  }
  
  // Check file extension (optional)
  final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  final hasValidExtension = validExtensions.any(
    (ext) => url.toLowerCase().endsWith(ext),
  );
  
  return hasValidExtension;
}
```

**Implementation**:
- Validate URLs before loading
- Reject non-HTTPS URLs
- Log suspicious URLs for monitoring

---

### 2. Permission Handling

**Risk**: Improper permission handling could expose user data or cause app rejection.

**Mitigation**:
- **Request Only When Needed**: Don't request permission on app launch
- **Clear Explanation**: Show why permission is needed before requesting
- **Handle Denial Gracefully**: Provide fallback options
- **Respect User Choice**: Don't repeatedly request denied permissions
- **Platform Configuration**:
  ```xml
  <!-- iOS: Info.plist -->
  <key>NSPhotoLibraryAddUsageDescription</key>
  <string>We need access to save images from chat to your photo library</string>
  
  <!-- Android: AndroidManifest.xml -->
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                   android:maxSdkVersion="28" />
  ```

---

### 3. Data Privacy

**Risk**: Cached images could be accessed by other apps or users.

**Mitigation**:
- **Secure Storage**: Use app-private directories for cache
- **Encryption**: Consider encrypting sensitive images (if needed)
- **Cache Expiration**: Clear old cached images periodically
- **User Control**: Provide option to clear cache manually

**Implementation**:
```dart
// Use secure app directory
final cacheDir = await getApplicationDocumentsDirectory();
final imageCacheDir = Directory('${cacheDir.path}/image_cache');

// Clear cache on logout
void clearImageCache() {
  if (imageCacheDir.existsSync()) {
    imageCacheDir.deleteSync(recursive: true);
  }
}
```

---

### 4. Network Security

**Risk**: Man-in-the-middle attacks could intercept image data.

**Mitigation**:
- **HTTPS Only**: Enforce HTTPS for all image URLs
- **Certificate Pinning**: Consider certificate pinning for critical apps
- **Timeout Configuration**: Set reasonable timeouts to prevent hanging
- **Error Handling**: Don't expose sensitive error details to users

**Implementation**:
```dart
final client = HttpClient()
  ..connectionTimeout = Duration(seconds: 30)
  ..badCertificateCallback = (cert, host, port) => false; // Reject bad certs
```

---

## Testing Strategy

### 1. Unit Tests

**ImageViewerController Tests**:
```dart
group('ImageViewerController', () {
  late ImageViewerController controller;
  
  setUp(() {
    controller = ImageViewerController();
  });
  
  test('init sets images and current index', () {
    final images = [mockImage1, mockImage2];
    controller.init(images, 1);
    
    expect(controller.images.length, 2);
    expect(controller.currentIndex.value, 1);
  });
  
  test('nextImage increments index', () {
    controller.init([mockImage1, mockImage2], 0);
    controller.nextImage();
    
    expect(controller.currentIndex.value, 1);
  });
  
  test('nextImage does not exceed bounds', () {
    controller.init([mockImage1], 0);
    controller.nextImage();
    
    expect(controller.currentIndex.value, 0);
  });
  
  test('saveImage handles success', () async {
    // Mock service
    final mockService = MockImageSaveService();
    when(mockService.saveImage(any))
      .thenAnswer((_) async => SaveImageResult.success());
    
    await controller.saveImage();
    
    expect(controller.error.value, '');
    expect(controller.isSaving.value, false);
  });
  
  test('saveImage handles permission denied', () async {
    final mockService = MockImageSaveService();
    when(mockService.saveImage(any))
      .thenAnswer((_) async => SaveImageResult.permissionDenied());
    
    await controller.saveImage();
    
    expect(controller.isSaving.value, false);
    // Verify dialog shown
  });
});
```

**ImageSaveService Tests**:
```dart
group('ImageSaveService', () {
  late ImageSaveService service;
  
  setUp(() {
    service = ImageSaveService();
  });
  
  test('hasPermission returns true when granted', () async {
    // Mock permission
    when(Permission.photos.status)
      .thenAnswer((_) async => PermissionStatus.granted);
    
    final result = await service.hasPermission();
    expect(result, true);
  });
  
  test('downloadImage returns bytes on success', () async {
    final mockClient = MockHttpClient();
    when(mockClient.get(any))
      .thenAnswer((_) async => http.Response(mockImageBytes, 200));
    
    final bytes = await service.downloadImage('https://example.com/image.jpg');
    expect(bytes, isNotEmpty);
  });
  
  test('downloadImage throws on failure', () async {
    final mockClient = MockHttpClient();
    when(mockClient.get(any))
      .thenAnswer((_) async => http.Response('Not Found', 404));
    
    expect(
      () => service.downloadImage('https://example.com/image.jpg'),
      throwsException,
    );
  });
});
```

**Coverage Target**: > 80%

---

### 2. Widget Tests

**ImageViewerPage Tests**:
```dart
group('ImageViewerPage', () {
  testWidgets('displays image counter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(
          images: [mockImage1, mockImage2, mockImage3],
          initialIndex: 1,
        ),
      ),
    );
    
    expect(find.text('2/3'), findsOneWidget);
  });
  
  testWidgets('close button pops page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(
          images: [mockImage1],
          initialIndex: 0,
        ),
      ),
    );
    
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    
    // Verify navigation
  });
  
  testWidgets('swipe changes image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(
          images: [mockImage1, mockImage2],
          initialIndex: 0,
        ),
      ),
    );
    
    // Swipe left
    await tester.drag(find.byType(ExtendedImageGesturePageView), Offset(-300, 0));
    await tester.pumpAndSettle();
    
    expect(find.text('2/2'), findsOneWidget);
  });
});
```

**Coverage Target**: > 70%

---

### 3. Integration Tests

**Complete Flow Test**:
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Image Viewer Integration', () {
    testWidgets('complete image viewing flow', (tester) async {
      // 1. Launch app
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      
      // 2. Navigate to chat with images
      await tester.tap(find.text('Test Chat'));
      await tester.pumpAndSettle();
      
      // 3. Tap image message
      await tester.tap(find.byType(ImageMessageBubble).first);
      await tester.pumpAndSettle();
      
      // 4. Verify viewer opened
      expect(find.byType(ImageViewerPage), findsOneWidget);
      expect(find.text('1/5'), findsOneWidget);
      
      // 5. Swipe to next image
      await tester.drag(find.byType(ExtendedImageGesturePageView), Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/5'), findsOneWidget);
      
      // 6. Pinch to zoom (simulate)
      // Note: Gesture simulation is complex, may need manual testing
      
      // 7. Tap save button
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();
      
      // 8. Handle permission dialog (if shown)
      // This depends on device state
      
      // 9. Close viewer
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      
      // 10. Verify back in chat
      expect(find.byType(ImageViewerPage), findsNothing);
    });
  });
}
```

---

### 4. Manual Testing Checklist

**Devices**:
- [ ] iPhone 12 (iOS 15)
- [ ] iPhone SE (iOS 14)
- [ ] iPad Pro (iOS 15)
- [ ] Samsung Galaxy S21 (Android 12)
- [ ] Google Pixel 5 (Android 11)
- [ ] Xiaomi device (Android 10)

**Scenarios**:
- [ ] Open single image
- [ ] Browse multiple images (swipe left/right)
- [ ] Pinch to zoom (0.5x - 3.0x)
- [ ] Double-tap to zoom (1x ↔ 2x)
- [ ] Pan zoomed image
- [ ] Save image (permission granted)
- [ ] Save image (permission denied)
- [ ] Save image (permission permanently denied)
- [ ] Close with back button
- [ ] Close with close button
- [ ] Close by tapping background
- [ ] Hero animation (open/close)
- [ ] Rotate device (portrait ↔ landscape)
- [ ] Weak network (slow loading)
- [ ] No network (error handling)
- [ ] Very large image (10MB+)
- [ ] Very small image (< 100KB)
- [ ] GIF animation
- [ ] WebP format
- [ ] Memory usage (< 50MB increase)
- [ ] Battery drain (< 5% per 10 min)

**Edge Cases**:
- [ ] Single image (no swipe)
- [ ] 100+ images in chat
- [ ] Image load failure
- [ ] Network timeout
- [ ] App backgrounded during save
- [ ] Low storage space
- [ ] Low memory warning

---

## Deployment Strategy

### Phase 1: MVP (Week 1)

**Scope**:
- Core image viewing (zoom, pan, swipe)
- Save to gallery
- Hero animation
- Basic error handling

**Rollout**:
1. Internal testing (2 days)
2. Beta release to 10% users (2 days)
3. Monitor metrics and crash reports
4. Fix critical bugs
5. Gradual rollout to 100% (3 days)

**Success Criteria**:
- Crash rate < 0.1%
- Feature usage > 30%
- User satisfaction > 85%

---

### Phase 2: Enhancement (Week 2)

**Scope**:
- Share functionality
- Rotate image
- Swipe-down to close
- Improved UI/UX

**Rollout**:
1. Internal testing (1 day)
2. Beta release to 25% users (2 days)
3. Monitor metrics
4. Gradual rollout to 100% (2 days)

**Success Criteria**:
- Share usage > 10%
- User satisfaction > 90%
- No performance regression

---

### Phase 3: Advanced (Optional)

**Scope**:
- Image editing (crop, annotate)
- Image info display
- Copy to clipboard
- Quality selection

**Rollout**:
1. Feature flag enabled for beta users
2. Collect feedback
3. Iterate based on feedback
4. Gradual rollout

**Success Criteria**:
- Advanced feature usage > 5%
- User satisfaction maintained
- No significant performance impact

---

### Monitoring and Metrics

**Key Metrics**:
```dart
// Track feature usage
Analytics.logEvent('image_viewer_opened', {
  'image_count': images.length,
  'initial_index': initialIndex,
});

Analytics.logEvent('image_saved', {
  'success': result.success,
  'permission_denied': result.permissionDenied,
});

Analytics.logEvent('image_viewer_closed', {
  'images_viewed': viewedCount,
  'time_spent_seconds': duration.inSeconds,
});
```

**Performance Monitoring**:
- Image load time (p50, p95, p99)
- Memory usage (average, peak)
- Crash rate
- ANR (Application Not Responding) rate
- Battery drain

**User Feedback**:
- In-app feedback prompt after using feature
- App store reviews mentioning image viewer
- Support tickets related to image viewing

---

## Appendix

### A. File Structure

```
lib/features/chats/
├── models/
│   └── image_viewer_item.dart              # New
├── controllers/
│   ├── sdk_chat_detail_controller.dart     # Modified (add navigation)
│   └── image_viewer_controller.dart        # New
├── views/
│   ├── pages/
│   │   └── image_viewer_page.dart          # New
│   └── widgets/
│       ├── bubbles/
│       │   └── image_message_bubble.dart   # Modified (add onTap)
│       └── image_viewer/
│           ├── image_viewer_top_bar.dart   # New
│           ├── image_viewer_bottom_bar.dart # New
│           └── image_viewer_loading.dart   # New
└── services/
    └── image_save_service.dart             # New
```

---

### B. Dependencies

```yaml
dependencies:
  extended_image: ^8.2.0
  image_gallery_saver: ^2.0.3
  permission_handler: ^11.0.1
  share_plus: ^7.2.1  # Phase 2
  
dev_dependencies:
  mockito: ^5.4.0
  integration_test:
    sdk: flutter
```

---

### C. Platform Configuration

**iOS (Info.plist)**:
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need access to save images from chat to your photo library</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to save images</string>
```

**Android (AndroidManifest.xml)**:
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                 android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

**Android (build.gradle)**:
```gradle
android {
    compileSdkVersion 33
    
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 33
    }
}
```

---

### D. References

- [extended_image Documentation](https://pub.dev/packages/extended_image)
- [image_gallery_saver Documentation](https://pub.dev/packages/image_gallery_saver)
- [permission_handler Documentation](https://pub.dev/packages/permission_handler)
- [Flutter Gestures Guide](https://docs.flutter.dev/ui/interactivity/gestures)
- [iOS Human Interface Guidelines - Photos](https://developer.apple.com/design/human-interface-guidelines/photos)
- [Material Design - Image Lists](https://m3.material.io/components/image-lists/overview)
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)

---

### E. Related Issues

- **WISE2018-34685**: Message Protocol Field Standardization (Completed)
  - Standardized `imageUrl`, `imageWidth`, `imageHeight` fields
  - Provides clean data model for image viewer
  
- **Future Enhancements**:
  - Video player integration
  - File viewer for documents
  - Image editing capabilities
  - Cloud storage integration

---

## Document Status

**Status**: ✅ Ready for Review  
**Next Steps**:
1. Review and approve architecture
2. Create Epic and Stories
3. Begin Phase 1 implementation

**Estimated Timeline**:
- Phase 1 (MVP): 3 days
- Phase 2 (Enhancement): 2 days
- Phase 3 (Advanced): 2 days (optional)
- Total: 5-7 days

**Risk Level**: Low  
- Using mature, well-tested libraries
- Clear requirements and design
- Incremental rollout strategy

---

**Document Version**: 0.1  
**Last Updated**: 2026-03-05  
**Author**: allen (AI-assisted)  
**Reviewers**: TBD

