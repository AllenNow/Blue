# Epic 3: Chat Integration and Navigation

**Epic ID**: WISE2018-34808-E3  
**Epic Title**: Chat Integration and Navigation  
**Priority**: P0 (Critical)  
**Estimated Effort**: 1 day  
**Dependencies**: Epic 1 (Foundation), Epic 2 (Viewer UI)  
**Phase**: Phase 1 MVP

---

## Epic Description

Integrate the image viewer with the existing chat interface, implement navigation logic, and ensure seamless user experience when opening and closing the viewer. This epic connects all components into a working feature.

**Technical Scope**:
- Modify ImageMessageBubble to add tap handler
- Implement navigation logic
- Extract image list from chat messages
- Handle Hero animation tags
- Implement save image flow with permission handling
- Add user feedback (toasts, dialogs)
- Integration testing

**Architecture Components**:
- Modified: `ImageMessageBubble`
- Modified: `SdkChatDetailController` (optional helper methods)
- New: Navigation utilities
- New: Permission dialogs

---

## Stories

### Story 3.1: Add Navigation Logic to ImageMessageBubble

**Story ID**: WISE2018-34808-S3.1  
**Title**: Add Navigation Logic to ImageMessageBubble  
**Priority**: P0  
**Estimated Effort**: 3 hours  
**Technical Complexity**: Medium

**User Story**:
As a user, I want to tap on an image message to open the full-screen viewer so that I can view the image in detail.

**Technical Tasks**:
1. Modify `lib/features/chats/views/widgets/bubbles/image_message_bubble.dart`
2. Add `GestureDetector` or `InkWell` wrapper
3. Implement `onTap` handler:
   - Get current chat from `SdkChatDetailController`
   - Extract all image messages
   - Convert to `List<ImageViewerItem>`
   - Find current image index
   - Navigate to `ImageViewerPage`
4. Ensure Hero tag matches viewer
5. Add tap feedback (ripple effect)
6. Handle edge cases (no images, single image)
7. Write widget tests

**Acceptance Criteria**:
- [ ] Tapping image opens viewer
- [ ] Correct image displayed initially
- [ ] Hero animation smooth
- [ ] Tap feedback visible
- [ ] Works with single image
- [ ] Works with multiple images
- [ ] No navigation errors
- [ ] Widget tests pass

**Technical Notes**:
- Hero tag format: `'image_${message.uniqueId}'`
- Use `Navigator.push()` with `MaterialPageRoute`
- Filter messages: `messages.where((m) => m.type == SdkMessageType.image)`
- Find index: `images.indexWhere((item) => item.messageId == currentMessageId)`

**Files to Modify**:
- `lib/features/chats/views/widgets/bubbles/image_message_bubble.dart`

**Files to Create**:
- `test/features/chats/views/widgets/bubbles/image_message_bubble_navigation_test.dart`

---

### Story 3.2: Implement Save Image Flow with Permission Handling

**Story ID**: WISE2018-34808-S3.2  
**Title**: Implement Save Image Flow with Permission Handling  
**Priority**: P0  
**Estimated Effort**: 4 hours  
**Technical Complexity**: High

**User Story**:
As a user, I want to save images to my gallery with clear permission requests so that I can keep images I like.

**Technical Tasks**:
1. Implement `saveImage()` in `ImageViewerController`:
   - Set `isSaving.value = true`
   - Get current image
   - Call `ImageSaveService.saveImage()`
   - Handle result (success/failure/permission denied)
   - Show appropriate feedback
   - Set `isSaving.value = false`
2. Create permission dialog widget:
   - Explain why permission needed
   - "Open Settings" button
   - "Copy Link" fallback button
   - "Cancel" button
3. Implement success toast
4. Implement error toast
5. Handle permission permanently denied
6. Add analytics events
7. Write integration tests

**Acceptance Criteria**:
- [ ] Save button triggers save flow
- [ ] Permission requested on first save
- [ ] Success toast shows on successful save
- [ ] Error toast shows on failure
- [ ] Permission dialog shows when denied
- [ ] "Open Settings" opens system settings
- [ ] "Copy Link" copies image URL
- [ ] Loading indicator shows during save
- [ ] Button disabled during save
- [ ] Integration tests pass
- [ ] Works on iOS and Android

**Technical Notes**:
- Use `Get.snackbar()` for toasts
- Use `Get.dialog()` for permission dialog
- Open settings: `openAppSettings()` from permission_handler
- Copy link: Use `Clipboard.setData()`
- Analytics events:
  - `image_save_initiated`
  - `image_save_success`
  - `image_save_failed`
  - `image_save_permission_denied`

**Files to Modify**:
- `lib/features/chats/controllers/image_viewer_controller.dart`

**Files to Create**:
- `lib/features/chats/views/widgets/image_viewer/permission_dialog.dart`
- `test/features/chats/integration/save_image_flow_test.dart`

---

### Story 3.3: Implement Toolbar Toggle on Tap

**Story ID**: WISE2018-34808-S3.3  
**Title**: Implement Toolbar Toggle on Tap  
**Priority**: P1  
**Estimated Effort**: 2 hours  
**Technical Complexity**: Low

**User Story**:
As a user, I want to tap the image to hide/show toolbars so that I can view the image without distractions.

**Technical Tasks**:
1. Add `GestureDetector` to image area in `ImageViewerPage`
2. Implement `onTap` handler:
   - Call `controller.toggleToolbar()`
3. Animate toolbar visibility:
   - Fade animation (200ms)
   - Slide animation (optional)
4. Ensure tap doesn't interfere with zoom gestures
5. Add haptic feedback (optional)
6. Write widget tests

**Acceptance Criteria**:
- [ ] Tapping image toggles toolbar visibility
- [ ] Animation smooth (200ms fade)
- [ ] Doesn't interfere with zoom/pan
- [ ] Works in both visible and hidden states
- [ ] Haptic feedback on toggle (optional)
- [ ] Widget tests pass

**Technical Notes**:
- Use `AnimatedOpacity` for fade
- Use `AnimatedSlide` for slide (optional)
- Ensure gesture detector doesn't block ExtendedImage gestures
- Consider using `HapticFeedback.lightImpact()`

**Files to Modify**:
- `lib/features/chats/views/pages/image_viewer_page.dart`
- `lib/features/chats/controllers/image_viewer_controller.dart`

---

### Story 3.4: Add Navigation Helper Methods

**Story ID**: WISE2018-34808-S3.4  
**Title**: Add Navigation Helper Methods  
**Priority**: P1  
**Estimated Effort**: 2 hours  
**Technical Complexity**: Low

**User Story**:
As a developer, I want reusable navigation methods so that opening the image viewer is consistent and maintainable.

**Technical Tasks**:
1. Create `lib/features/chats/utils/image_viewer_navigation.dart`
2. Implement static helper methods:
   - `openImageViewer(BuildContext, List<SdkMessage>, String currentMessageId)`
   - `getImageMessages(List<SdkMessage>)` - filter image messages
   - `convertToViewerItems(List<SdkMessage>)` - convert to ImageViewerItem
   - `findImageIndex(List<ImageViewerItem>, String messageId)`
3. Add validation and error handling
4. Write unit tests
5. Update ImageMessageBubble to use helper

**Acceptance Criteria**:
- [ ] Helper methods created and documented
- [ ] Validation prevents invalid navigation
- [ ] Error handling for edge cases
- [ ] Unit tests pass with >90% coverage
- [ ] ImageMessageBubble uses helper
- [ ] Code is DRY and maintainable

**Technical Notes**:
- Return early if no images found
- Log warnings for invalid states
- Consider making this an extension on SdkChatDetailController

**Files to Create**:
- `lib/features/chats/utils/image_viewer_navigation.dart`
- `test/features/chats/utils/image_viewer_navigation_test.dart`

**Files to Modify**:
- `lib/features/chats/views/widgets/bubbles/image_message_bubble.dart`

---

### Story 3.5: Integration Testing and Bug Fixes

**Story ID**: WISE2018-34808-S3.5  
**Title**: Integration Testing and Bug Fixes  
**Priority**: P0  
**Estimated Effort**: 4 hours  
**Technical Complexity**: Medium

**User Story**:
As a developer, I need comprehensive integration tests to ensure the complete flow works correctly.

**Technical Tasks**:
1. Create integration test suite:
   - Open viewer from chat
   - Browse multiple images
   - Zoom and pan
   - Save image (with permission)
   - Close viewer
2. Test edge cases:
   - Single image
   - No images
   - Network failure
   - Permission denied
   - Low memory
3. Test on real devices:
   - iPhone (iOS 14+)
   - Android (API 21+)
4. Fix discovered bugs
5. Performance profiling
6. Memory leak detection

**Acceptance Criteria**:
- [ ] Integration tests cover main flow
- [ ] Edge cases tested
- [ ] Tests pass on iOS and Android
- [ ] No memory leaks detected
- [ ] Performance meets targets (60fps, <2s load)
- [ ] All discovered bugs fixed
- [ ] Test coverage >75%

**Technical Notes**:
- Use `integration_test` package
- Test on physical devices, not just simulators
- Use Flutter DevTools for profiling
- Check memory usage with Memory profiler
- Verify no frame drops during gestures

**Files to Create**:
- `integration_test/image_viewer_flow_test.dart`
- `integration_test/image_viewer_edge_cases_test.dart`

---

## Epic Success Criteria

- [ ] Image viewer accessible from chat
- [ ] Navigation smooth with Hero animation
- [ ] Save image flow works end-to-end
- [ ] Permission handling works correctly
- [ ] Toolbar toggle functional
- [ ] All integration tests passing
- [ ] No critical bugs
- [ ] Performance targets met
- [ ] Works on iOS and Android

---

## Technical Risks

1. **Hero Animation Issues**: Tag mismatch or animation glitches
   - Mitigation: Ensure consistent tag format, test thoroughly

2. **Permission Edge Cases**: Different behavior across OS versions
   - Mitigation: Test on multiple OS versions, handle all states

3. **Memory Leaks**: Controllers or listeners not disposed
   - Mitigation: Use DevTools Memory profiler, verify disposal

4. **Navigation Stack Issues**: Back button behavior
   - Mitigation: Test navigation thoroughly, handle WillPopScope if needed

---

## Dependencies

**Upstream**: Epic 1 (Foundation), Epic 2 (Viewer UI)  
**Downstream**: Epic 4 (Testing & Optimization) depends on this

---

**Epic Status**: 📝 Ready for Implementation  
**Next Epic**: Epic 4 - Testing, Optimization, and Phase 2 Features
