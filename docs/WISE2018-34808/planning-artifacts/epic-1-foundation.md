# Epic 1: Foundation - Core Infrastructure

**Epic ID**: WISE2018-34808-E1  
**Epic Title**: Foundation - Core Infrastructure  
**Priority**: P0 (Critical)  
**Estimated Effort**: 1 day  
**Dependencies**: None  
**Phase**: Phase 1 MVP

---

## Epic Description

Establish the foundational infrastructure for the Picture Viewer feature, including data models, dependency configuration, and core service setup. This epic provides the technical foundation that all other features will build upon.

**Technical Scope**:
- Add and configure third-party dependencies
- Create data models for image viewer
- Set up service layer architecture
- Configure platform permissions
- Establish project structure

**Architecture Components**:
- `ImageViewerItem` model
- `ImageSaveService` service
- Dependency injection setup
- Platform configuration (iOS/Android)

---

## Stories

### Story 1.1: Configure Dependencies and Platform Setup

**Story ID**: WISE2018-34808-S1.1  
**Title**: Configure Dependencies and Platform Setup  
**Priority**: P0  
**Estimated Effort**: 2 hours  
**Technical Complexity**: Low

**User Story**:
As a developer, I need to configure all required dependencies and platform permissions so that the image viewer can access necessary platform features.

**Technical Tasks**:
1. Add dependencies to `pubspec.yaml`:
   - `extended_image: ^8.2.0`
   - `image_gallery_saver: ^2.0.3`
   - `permission_handler: ^11.0.1`
2. Configure iOS permissions in `Info.plist`:
   - `NSPhotoLibraryAddUsageDescription`
   - `NSPhotoLibraryUsageDescription`
3. Configure Android permissions in `AndroidManifest.xml`:
   - `WRITE_EXTERNAL_STORAGE` (API < 29)
   - `READ_MEDIA_IMAGES` (API 33+)
4. Run `flutter pub get`
5. Verify no dependency conflicts

**Acceptance Criteria**:
- [ ] All dependencies added to pubspec.yaml
- [ ] iOS Info.plist configured with permission descriptions
- [ ] Android AndroidManifest.xml configured with permissions
- [ ] `flutter pub get` runs without errors
- [ ] No dependency version conflicts
- [ ] Build succeeds on both iOS and Android

**Technical Notes**:
- Use exact versions to avoid breaking changes
- Test on iOS 12+ and Android 5.0+ (API 21+)
- Verify permission descriptions are user-friendly

**Files to Modify**:
- `pubspec.yaml`
- `ios/Runner/Info.plist`
- `android/app/src/main/AndroidManifest.xml`

---

### Story 1.2: Create ImageViewerItem Data Model

**Story ID**: WISE2018-34808-S1.2  
**Title**: Create ImageViewerItem Data Model  
**Priority**: P0  
**Estimated Effort**: 1 hour  
**Technical Complexity**: Low

**User Story**:
As a developer, I need a data model to encapsulate image metadata so that the viewer can display and manage image information consistently.

**Technical Tasks**:
1. Create `lib/features/chats/models/image_viewer_item.dart`
2. Define `ImageViewerItem` class with properties:
   - `imageUrl` (String, required)
   - `thumbnailUrl` (String?, optional)
   - `messageId` (String, required)
   - `width` (int?, optional)
   - `height` (int?, optional)
   - `timestamp` (DateTime, required)
   - `senderName` (String?, optional)
3. Implement factory constructor `fromMessage(SdkMessage)`
4. Add `copyWith()` method
5. Add `toJson()` and `fromJson()` for serialization
6. Write unit tests

**Acceptance Criteria**:
- [ ] ImageViewerItem class created with all required properties
- [ ] Factory constructor converts SdkMessage to ImageViewerItem
- [ ] Handles ImageMessageContent correctly
- [ ] copyWith() method works for all properties
- [ ] JSON serialization/deserialization works
- [ ] Unit tests pass with >90% coverage
- [ ] Null safety properly handled

**Technical Notes**:
- Use `ImageMessageContent.imageUrl` (from WISE2018-34685)
- Handle optional fields gracefully
- Ensure immutability (final properties)

**Files to Create**:
- `lib/features/chats/models/image_viewer_item.dart`
- `test/features/chats/models/image_viewer_item_test.dart`

---

### Story 1.3: Create ImageSaveService

**Story ID**: WISE2018-34808-S1.3  
**Title**: Create ImageSaveService  
**Priority**: P0  
**Estimated Effort**: 3 hours  
**Technical Complexity**: Medium

**User Story**:
As a developer, I need a service to handle image downloading and saving so that users can save images to their device gallery with proper permission handling.

**Technical Tasks**:
1. Create `lib/features/chats/services/image_save_service.dart`
2. Implement `ImageSaveService` class with methods:
   - `hasPermission()` - Check gallery permission status
   - `requestPermission()` - Request gallery permission
   - `downloadImage(String url)` - Download image from URL
   - `saveToGallery(Uint8List bytes)` - Save image to gallery
   - `saveImage(String url)` - Complete save flow
3. Create `SaveImageResult` class for result handling
4. Implement error handling and retry logic
5. Add logging for debugging
6. Write unit tests with mocked dependencies

**Acceptance Criteria**:
- [ ] ImageSaveService class created with all methods
- [ ] Permission checking works on iOS and Android
- [ ] Permission request shows system dialog
- [ ] Image download handles network errors
- [ ] Save to gallery works on both platforms
- [ ] SaveImageResult properly indicates success/failure/permission denied
- [ ] Unit tests pass with >80% coverage
- [ ] Error messages are clear and actionable

**Technical Notes**:
- Use `permission_handler` for cross-platform permissions
- Use `http` package for image download
- Use `image_gallery_saver` for saving
- Handle permission permanently denied case
- Add timeout for network requests (30s)

**Files to Create**:
- `lib/features/chats/services/image_save_service.dart`
- `test/features/chats/services/image_save_service_test.dart`

---

### Story 1.4: Set Up Dependency Injection

**Story ID**: WISE2018-34808-S1.4  
**Title**: Set Up Dependency Injection  
**Priority**: P0  
**Estimated Effort**: 1 hour  
**Technical Complexity**: Low

**User Story**:
As a developer, I need to register services in the dependency injection container so that they can be accessed throughout the app.

**Technical Tasks**:
1. Register `ImageSaveService` in GetX dependency injection
2. Add initialization in app startup
3. Ensure `SdkFileCacheService` is available
4. Verify service lifecycle management
5. Add integration test for DI setup

**Acceptance Criteria**:
- [ ] ImageSaveService registered in GetX
- [ ] Service can be retrieved with Get.find<ImageSaveService>()
- [ ] Service is singleton (same instance reused)
- [ ] No circular dependencies
- [ ] Integration test verifies DI setup

**Technical Notes**:
- Use `Get.put()` or `Get.lazyPut()` appropriately
- Register during app initialization
- Consider lazy loading for performance

**Files to Modify**:
- `lib/main.dart` or dependency injection setup file
- `test/integration/di_setup_test.dart`

---

## Epic Success Criteria

- [ ] All dependencies configured and working
- [ ] Data models created and tested
- [ ] Services implemented and tested
- [ ] Dependency injection set up
- [ ] Platform permissions configured
- [ ] All unit tests passing (>85% coverage)
- [ ] Build succeeds on iOS and Android
- [ ] No breaking changes to existing code

---

## Technical Risks

1. **Dependency Conflicts**: extended_image may conflict with existing image packages
   - Mitigation: Test thoroughly, use dependency overrides if needed

2. **Permission Handling**: Different behavior on iOS vs Android
   - Mitigation: Test on both platforms, handle edge cases

3. **Platform Configuration**: Missing permissions cause runtime crashes
   - Mitigation: Verify configuration, add runtime checks

---

## Dependencies

**Upstream**: None (foundation epic)  
**Downstream**: Epic 2, 3, 4 all depend on this

---

**Epic Status**: 📝 Ready for Implementation  
**Next Epic**: Epic 2 - Image Viewer UI Components
