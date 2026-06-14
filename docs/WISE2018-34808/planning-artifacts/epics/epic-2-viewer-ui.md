# Epic 2: Image Viewer UI Components

**Epic ID**: WISE2018-34808-E2  
**Epic Title**: Image Viewer UI Components  
**Priority**: P0 (Critical)  
**Estimated Effort**: 2 days  
**Dependencies**: Epic 1 (Foundation)  
**Phase**: Phase 1 MVP

---

## Epic Description

Implement the core UI components for the image viewer, including the full-screen page, gesture handling, multi-image browsing, and toolbar components. This epic delivers the primary user-facing functionality.

**Technical Scope**:
- ImageViewerController (state management)
- ImageViewerPage (full-screen view)
- ExtendedImage integration (zoom, pan, gestures)
- ExtendedImageGesturePageView (multi-image browsing)
- Top bar (close button, counter)
- Bottom bar (action buttons)
- Loading and error states

**Architecture Components**:
- Controller: `ImageViewerController`
- Page: `ImageViewerPage`
- Widgets: `ImageViewerTopBar`, `ImageViewerBottomBar`, `ImageViewerLoading`

---

## Stories

### Story 2.1: Create ImageViewerController

**Story ID**: WISE2018-34808-S2.1  
**Title**: Create ImageViewerController  
**Priority**: P0  
**Estimated Effort**: 3 hours  
**Technical Complexity**: Medium

**User Story**:
As a developer, I need a controller to manage image viewer state so that the UI can react to user actions and state changes.

**Technical Tasks**:
1. Create `lib/features/chats/controllers/image_viewer_controller.dart`
2. Extend `GetxController`
3. Define observable state:
   - `images: RxList<ImageViewerItem>`
   - `currentIndex: RxInt`
   - `isLoading: RxBool`
   - `isSaving: RxBool`
   - `error: RxString`
   - `showToolbar: RxBool`
4. Implement methods:
   - `init(List<ImageViewerItem>, int initialIndex)`
   - `nextImage()`
   - `previousImage()`
   - `jumpToImage(int index)`
   - `saveImage()`
   - `toggleToolbar()`
5. Manage `PageController` lifecycle
6. Inject `ImageSaveService`
7. Write unit tests

**Acceptance Criteria**:
- [ ] ImageViewerController created with all state properties
- [ ] All methods implemented and working
- [ ] PageController properly initialized and disposed
- [ ] State changes trigger UI updates (Obx)
- [ ] saveImage() integrates with ImageSaveService
- [ ] Error handling for all operations
- [ ] Unit tests pass with >85% coverage
- [ ] No memory leaks (controller properly disposed)

**Technical Notes**:
- Use `late PageController` for lazy initialization
- Dispose PageController in `onClose()`
- Handle edge cases (empty list, invalid index)
- Add debouncing for rapid navigation if needed

**Files to Create**:
- `lib/features/chats/controllers/image_viewer_controller.dart`
- `test/features/chats/controllers/image_viewer_controller_test.dart`

---

### Story 2.2: Implement ImageViewerPage Core Structure

**Story ID**: WISE2018-34808-S2.2  
**Title**: Implement ImageViewerPage Core Structure  
**Priority**: P0  
**Estimated Effort**: 4 hours  
**Technical Complexity**: High

**User Story**:
As a user, I want to view images in full-screen mode so that I can see image details clearly.

**Technical Tasks**:
1. Create `lib/features/chats/views/pages/image_viewer_page.dart`
2. Implement `ImageViewerPage` as StatelessWidget
3. Set up GetX controller binding
4. Create black background Scaffold
5. Implement ExtendedImageGesturePageView:
   - Configure for horizontal scrolling
   - Set up page change callback
   - Implement item builder
6. Integrate ExtendedImage for single image:
   - Set mode to `ExtendedImageMode.gesture`
   - Configure gesture parameters (min/max scale)
   - Implement double-tap zoom
   - Add loading state
   - Add error state
7. Implement Hero animation
8. Handle system UI (hide status bar)
9. Add widget tests

**Acceptance Criteria**:
- [ ] Full-screen page with black background
- [ ] Images display correctly
- [ ] Horizontal swipe navigation works
- [ ] Pinch to zoom works (0.5x - 3.0x)
- [ ] Double-tap zoom works (1x ↔ 2x)
- [ ] Pan works when zoomed
- [ ] Hero animation smooth (300ms)
- [ ] Loading indicator shows during load
- [ ] Error state shows on failure
- [ ] Status bar hidden in viewer
- [ ] Widget tests pass
- [ ] No performance issues (60fps)

**Technical Notes**:
- Use `SystemChrome.setEnabledSystemUIMode()` to hide status bar
- Restore system UI on page dispose
- Configure gesture with `GestureConfig`:
  ```dart
  minScale: 0.5
  maxScale: 3.0
  animationMinScale: 0.5
  animationMaxScale: 3.5
  speed: 1.0
  inertialSpeed: 100.0
  ```
- Use `cacheWidth` and `cacheHeight` to limit memory

**Files to Create**:
- `lib/features/chats/views/pages/image_viewer_page.dart`
- `test/features/chats/views/pages/image_viewer_page_test.dart`

---

### Story 2.3: Create ImageViewerTopBar Widget

**Story ID**: WISE2018-34808-S2.3  
**Title**: Create ImageViewerTopBar Widget  
**Priority**: P0  
**Estimated Effort**: 2 hours  
**Technical Complexity**: Low

**User Story**:
As a user, I want to see which image I'm viewing and easily close the viewer so that I can navigate and exit efficiently.

**Technical Tasks**:
1. Create `lib/features/chats/views/widgets/image_viewer/image_viewer_top_bar.dart`
2. Implement positioned widget at top
3. Add semi-transparent gradient background
4. Add close button (left side)
5. Add image counter (right side, e.g., "3/10")
6. Handle safe area insets
7. Observe controller state with Obx
8. Add tap animations
9. Write widget tests

**Acceptance Criteria**:
- [ ] Top bar positioned correctly
- [ ] Gradient background (black to transparent)
- [ ] Close button visible and functional
- [ ] Image counter updates on swipe
- [ ] Safe area respected (notch, status bar)
- [ ] Toolbar visibility toggles with controller
- [ ] Tap animations smooth
- [ ] Widget tests pass
- [ ] Accessible (screen reader support)

**Technical Notes**:
- Use `Positioned` widget
- Gradient: `Colors.black.withOpacity(0.6)` to `Colors.transparent`
- Counter format: `"${currentIndex + 1}/${totalImages}"`
- Close button triggers `Navigator.pop()`

**Files to Create**:
- `lib/features/chats/views/widgets/image_viewer/image_viewer_top_bar.dart`
- `test/features/chats/views/widgets/image_viewer/image_viewer_top_bar_test.dart`

---

### Story 2.4: Create ImageViewerBottomBar Widget

**Story ID**: WISE2018-34808-S2.4  
**Title**: Create ImageViewerBottomBar Widget  
**Priority**: P0  
**Estimated Effort**: 2 hours  
**Technical Complexity**: Low

**User Story**:
As a user, I want to access image actions (save, share, rotate) so that I can perform operations on the viewed image.

**Technical Tasks**:
1. Create `lib/features/chats/views/widgets/image_viewer/image_viewer_bottom_bar.dart`
2. Implement positioned widget at bottom
3. Add semi-transparent gradient background
4. Add action buttons:
   - Save button (with loading state)
   - Share button (Phase 2, disabled for now)
   - Rotate button (Phase 2, disabled for now)
5. Handle safe area insets (home indicator)
6. Observe controller state with Obx
7. Show loading indicator on save
8. Write widget tests

**Acceptance Criteria**:
- [ ] Bottom bar positioned correctly
- [ ] Gradient background (black to transparent)
- [ ] Save button visible and functional
- [ ] Loading state shows during save
- [ ] Safe area respected (home indicator)
- [ ] Toolbar visibility toggles with controller
- [ ] Buttons evenly spaced
- [ ] Widget tests pass
- [ ] Accessible (screen reader support)

**Technical Notes**:
- Use `Positioned` widget
- Gradient: `Colors.black.withOpacity(0.6)` to `Colors.transparent`
- Save button triggers `controller.saveImage()`
- Show `CircularProgressIndicator` when `isSaving.value == true`
- Disable buttons during save operation

**Files to Create**:
- `lib/features/chats/views/widgets/image_viewer/image_viewer_bottom_bar.dart`
- `test/features/chats/views/widgets/image_viewer/image_viewer_bottom_bar_test.dart`

---

### Story 2.5: Implement Loading and Error States

**Story ID**: WISE2018-34808-S2.5  
**Title**: Implement Loading and Error States  
**Priority**: P0  
**Estimated Effort**: 2 hours  
**Technical Complexity**: Low

**User Story**:
As a user, I want to see loading indicators and error messages so that I understand what's happening when images load or fail.

**Technical Tasks**:
1. Create `lib/features/chats/views/widgets/image_viewer/image_viewer_loading.dart`
2. Implement loading widget:
   - Centered `CircularProgressIndicator`
   - Optional progress percentage (if available)
   - Loading text
3. Implement error widget:
   - Error icon
   - Error message
   - Retry button
4. Integrate with ExtendedImage `loadStateChanged`
5. Add fade-in animation for loaded images
6. Write widget tests

**Acceptance Criteria**:
- [ ] Loading indicator shows during image load
- [ ] Error state shows on load failure
- [ ] Retry button reloads image
- [ ] Fade-in animation smooth (300ms)
- [ ] Loading text clear and helpful
- [ ] Error messages user-friendly
- [ ] Widget tests pass
- [ ] Accessible (screen reader support)

**Technical Notes**:
- Use `ExtendedImage.loadStateChanged` callback
- Handle three states: loading, completed, failed
- Provide helpful error messages:
  - Network error: "Unable to load image. Check your connection."
  - Timeout: "Image loading timed out. Please try again."
  - Invalid URL: "Invalid image URL."

**Files to Create**:
- `lib/features/chats/views/widgets/image_viewer/image_viewer_loading.dart`
- `test/features/chats/views/widgets/image_viewer/image_viewer_loading_test.dart`

---

## Epic Success Criteria

- [ ] Full-screen image viewer functional
- [ ] Zoom and pan gestures work smoothly
- [ ] Multi-image browsing works
- [ ] Top and bottom bars functional
- [ ] Loading and error states handled
- [ ] Hero animation smooth
- [ ] All widget tests passing
- [ ] Performance: 60fps during gestures
- [ ] Memory: < 50MB increase
- [ ] No UI jank or stuttering

---

## Technical Risks

1. **Gesture Conflicts**: ExtendedImage gestures may conflict with PageView
   - Mitigation: Configure gesture priorities, test thoroughly

2. **Memory Usage**: Multiple high-res images in PageView
   - Mitigation: Use cacheWidth/cacheHeight, limit preloaded pages

3. **Performance**: Smooth 60fps during zoom/pan
   - Mitigation: Use GPU acceleration, profile with DevTools

---

## Dependencies

**Upstream**: Epic 1 (Foundation) - requires ImageViewerItem, ImageSaveService  
**Downstream**: Epic 3 (Integration) depends on this

---

**Epic Status**: 📝 Ready for Implementation  
**Next Epic**: Epic 3 - Chat Integration and Navigation
