// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Yuz';

  @override
  String get splashTagline => 'Beauty, processed on your device';

  @override
  String get actionNext => 'Next';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionGetStarted => 'Get started';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionOpenSettings => 'Open settings';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get onboardingTitle1 => 'Real-time beauty camera';

  @override
  String get onboardingBody1 => 'Natural skin smoothing that keeps your texture, rendered live on the GPU.';

  @override
  String get onboardingTitle2 => 'Private by design';

  @override
  String get onboardingBody2 =>
      'Camera effects run entirely on your phone. Nothing is uploaded for on-device features.';

  @override
  String get onboardingTitle3 => 'Your look, your presets';

  @override
  String get onboardingBody3 => 'Fine-tune every effect from 0 to 100 and save your favourite combinations.';

  @override
  String get permissionTitle => 'Camera access';

  @override
  String get permissionBody =>
      'Yuz needs the camera to show the live beauty preview and take photos. Frames stay on your device.';

  @override
  String get permissionGrant => 'Allow camera';

  @override
  String get permissionDenied => 'Camera access was denied. The camera features stay unavailable until you allow it.';

  @override
  String get permissionPermanentlyDenied => 'Camera access is blocked. Enable it for Yuz in system settings.';

  @override
  String get homeGreeting => 'Create your look';

  @override
  String get homeSectionCamera => 'Camera';

  @override
  String get homeSectionEditing => 'Editing';

  @override
  String get homeSectionAi => 'AI studio';

  @override
  String get homeSectionAccount => 'Account';

  @override
  String get featureBeautyCamera => 'Beauty camera';

  @override
  String get featureBeautyCameraSubtitle => 'Live skin smoothing';

  @override
  String get featurePhotoEditor => 'Photo editor';

  @override
  String get featureVideoEditor => 'Video editor';

  @override
  String get featureAiPhotoshoot => 'AI photoshoot';

  @override
  String get featureAiHairstyle => 'AI hairstyle';

  @override
  String get featureAiMakeup => 'AI makeup';

  @override
  String get featureAiBackground => 'AI background';

  @override
  String get featureTemplates => 'Templates';

  @override
  String get featureProjects => 'Projects';

  @override
  String get featurePremium => 'Premium';

  @override
  String get featureCredits => 'Credits';

  @override
  String get featureProfile => 'Profile';

  @override
  String get featureSettings => 'Settings';

  @override
  String get featureHelp => 'Help';

  @override
  String get statusImplemented => 'Ready';

  @override
  String get statusPartial => 'Preview';

  @override
  String get statusNotStarted => 'Planned';

  @override
  String get featureUnavailableTitle => 'Not available yet';

  @override
  String featureUnavailableBody(String feature, int phase) {
    return '$feature is planned for development phase $phase. It is not part of this build.';
  }

  @override
  String get beautyReset => 'Reset';

  @override
  String get beautyUndo => 'Undo';

  @override
  String get beautySavePreset => 'Save preset';

  @override
  String get beautyPresetNameHint => 'Preset name';

  @override
  String get beautyPresets => 'Presets';

  @override
  String get beautyPresetNatural => 'Natural';

  @override
  String get beautyPresetSoft => 'Soft';

  @override
  String get beautyPresetGlow => 'Glow';

  @override
  String beautyPresetSaved(String name) {
    return 'Preset “$name” saved';
  }

  @override
  String get cameraSwitch => 'Switch camera';

  @override
  String get cameraCapture => 'Take photo';

  @override
  String get cameraTimer => 'Timer';

  @override
  String get cameraTimerOff => 'Timer off';

  @override
  String cameraTimerSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get cameraFlash => 'Flash';

  @override
  String get cameraFlashOff => 'Flash off';

  @override
  String get cameraFlashAuto => 'Flash auto';

  @override
  String get cameraFlashOn => 'Flash on';

  @override
  String get cameraFlashTorch => 'Torch';

  @override
  String get cameraZoom => 'Zoom';

  @override
  String get cameraExposure => 'Exposure';

  @override
  String get cameraNoFace => 'No face detected';

  @override
  String cameraFacesDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count faces', one: '1 face');
    return '$_temp0';
  }

  @override
  String get cameraTrackingUnavailable => 'Face tracking unavailable — skin tone detection only';

  @override
  String get cameraStarting => 'Starting camera…';

  @override
  String cameraMeasuredFps(String fps, String gpu, String detector) {
    return '$fps FPS · GPU $gpu ms · face $detector ms';
  }

  @override
  String get cameraPhotoSaved => 'Photo saved';

  @override
  String get errorPermissionDenied => 'Camera permission is required.';

  @override
  String get errorCameraUnavailable => 'The camera is not available on this device right now.';

  @override
  String get errorCameraInUse => 'Another app is using the camera.';

  @override
  String get errorCameraDisconnected => 'The camera was disconnected.';

  @override
  String get errorGpu => 'This device\'s GPU could not start the beauty engine.';

  @override
  String get errorCaptureFailed => 'The photo could not be saved.';

  @override
  String get errorThermal => 'The phone is hot — face tracking is paused to cool down.';

  @override
  String get errorUnknown => 'Something went wrong.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsPerformanceOverlay => 'Show measured performance';

  @override
  String get settingsPerformanceOverlaySubtitle => 'FPS, GPU and face-tracking timings measured on device';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsResetOnboarding => 'Show onboarding again';

  @override
  String get languageUzbek => 'Oʻzbekcha';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get privacyOnDeviceTitle => 'On-device processing';

  @override
  String get privacyOnDeviceBody =>
      'Live camera effects, skin smoothing and face tracking run on your phone. These features never send images to a server.';

  @override
  String get privacyStorageTitle => 'What is stored';

  @override
  String get privacyStorageBody =>
      'Photos you take are saved in the app\'s private storage. Your settings and beauty presets are stored locally.';

  @override
  String get privacyCloudTitle => 'Cloud AI features';

  @override
  String get privacyCloudBody =>
      'Cloud AI features ask for your explicit consent before any photo is uploaded. Only the photo you choose is sent, over an encrypted connection; it is deleted from the server after processing and never used for advertising or model training. You can withdraw consent in Account.';

  @override
  String get privacyDeletionTitle => 'Deleting your data';

  @override
  String get privacyDeletionBody =>
      'Uninstalling the app removes all locally stored photos, presets and settings. Your account and everything stored on the server can be deleted in Account.';

  @override
  String get tabLooks => 'Looks';

  @override
  String get tabFilters => 'Filters';

  @override
  String get tabSkin => 'Skin';

  @override
  String get tabFace => 'Face';

  @override
  String get tabReshape => 'Reshape';

  @override
  String get tabMakeup => 'Makeup';

  @override
  String get tabCamera => 'Camera';

  @override
  String get effectSkinSmoothing => 'Smooth';

  @override
  String get effectTexturePreservation => 'Texture';

  @override
  String get effectSkinBrightening => 'Brighten';

  @override
  String get effectSkinTone => 'Even tone';

  @override
  String get effectBlemishReduction => 'Blemishes';

  @override
  String get effectShineReduction => 'Matte';

  @override
  String get effectGlow => 'Glow';

  @override
  String get effectEyeBrightening => 'Bright eyes';

  @override
  String get effectTeethWhitening => 'Teeth';

  @override
  String get effectDarkCircles => 'Dark circles';

  @override
  String get effectFaceSlim => 'Slim face';

  @override
  String get effectJawline => 'Jawline';

  @override
  String get effectChin => 'Chin';

  @override
  String get effectEyeEnlarge => 'Bigger eyes';

  @override
  String get effectNoseSlim => 'Nose';

  @override
  String get effectLips => 'Fuller lips';

  @override
  String get effectForehead => 'Forehead';

  @override
  String get effectLipstick => 'Lipstick';

  @override
  String get effectBlush => 'Blush';

  @override
  String get effectEyebrows => 'Brows';

  @override
  String get effectEyeshadow => 'Eyeshadow';

  @override
  String get effectEyeliner => 'Eyeliner';

  @override
  String get effectMakeupIntensity => 'Makeup';

  @override
  String get effectFilterIntensity => 'Intensity';

  @override
  String get filterNone => 'Original';

  @override
  String get filterNatural => 'Natural';

  @override
  String get filterSoft => 'Soft';

  @override
  String get filterGlow => 'Glow';

  @override
  String get filterPortrait => 'Portrait';

  @override
  String get filterCinematic => 'Cinematic';

  @override
  String get filterWarm => 'Warm';

  @override
  String get filterCool => 'Cool';

  @override
  String get filterVintage => 'Vintage';

  @override
  String get filterBlackWhite => 'B&W';

  @override
  String get filterCustom => 'My LUT';

  @override
  String get filterImport => 'Import LUT';

  @override
  String get lutImported => 'Custom LUT imported';

  @override
  String get lutImportWrongSize => 'A LUT image must be 512×512 pixels.';

  @override
  String get lutImportUnreadable => 'This image could not be read.';

  @override
  String get beautyPresetEverydayMakeup => 'Everyday';

  @override
  String get beautyPresetEveningMakeup => 'Evening';

  @override
  String get requiresFaceTracking => 'Needs face tracking — face the camera';

  @override
  String get makeupShade => 'Shade';

  @override
  String get effectSharpen => 'Sharpen';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectsNew => 'New photo';

  @override
  String get projectsEmptyTitle => 'No projects yet';

  @override
  String get projectsEmptyBody => 'Import a photo to retouch it. Your original is never changed.';

  @override
  String get projectsDeleteTitle => 'Delete project?';

  @override
  String get projectsDeleteBody =>
      'The copy, edits and exports stored in the app are removed. Photos already saved to your gallery stay.';

  @override
  String get projectsImportFailed => 'This file could not be imported.';

  @override
  String get photoRetouchTitle => 'Retouch';

  @override
  String get photoNext => 'Edit';

  @override
  String get photoCompare => 'Hold to compare';

  @override
  String get photoPreparing => 'Preparing full-resolution image…';

  @override
  String get photoNotFound => 'This project no longer exists.';

  @override
  String get photoRenderFailed => 'The photo could not be processed.';

  @override
  String get photoSavedToGallery => 'Saved to your gallery';

  @override
  String get photoSavedInApp => 'Saved in Yuz (no gallery access)';

  @override
  String get photoSaveFailed => 'The edit could not be saved.';

  @override
  String get editorPaint => 'Draw';

  @override
  String get editorText => 'Text';

  @override
  String get editorCrop => 'Crop';

  @override
  String get editorTune => 'Adjust';

  @override
  String get editorBlur => 'Blur';

  @override
  String get editorEmoji => 'Emoji';

  @override
  String get editorStickers => 'Stickers';

  @override
  String get editorBrightness => 'Brightness';

  @override
  String get editorContrast => 'Contrast';

  @override
  String get editorSaturation => 'Saturation';

  @override
  String get editorExposure => 'Exposure';

  @override
  String get editorHue => 'Hue';

  @override
  String get editorTemperature => 'Temperature';

  @override
  String get editorFade => 'Fade';

  @override
  String get editorTint => 'Tint';

  @override
  String get editorRotate => 'Rotate';

  @override
  String get editorFlip => 'Flip';

  @override
  String get editorRatio => 'Ratio';

  @override
  String get editorReset => 'Reset';

  @override
  String get editorTextHint => 'Enter text';

  @override
  String get editorDone => 'Done';

  @override
  String get editorBack => 'Back';

  @override
  String get editorUndo => 'Undo';

  @override
  String get editorRedo => 'Redo';

  @override
  String get editorRemove => 'Remove';

  @override
  String get editorEdit => 'Edit';

  @override
  String get editorApplying => 'Applying changes…';

  @override
  String get editorLoading => 'Please wait…';

  @override
  String get editorCloseTitle => 'Close the editor?';

  @override
  String get editorCloseBody => 'Your edits are kept in the project.';

  @override
  String get editorEraser => 'Eraser';

  @override
  String get editorLineWidth => 'Line width';

  @override
  String get editorOpacity => 'Opacity';

  @override
  String get editorColor => 'Color';

  @override
  String get editorSearch => 'Search';

  @override
  String get editorAlign => 'Align text';

  @override
  String get editorRotateScale => 'Rotate and scale';

  @override
  String get cameraModePhoto => 'Photo';

  @override
  String get cameraModeVideo => 'Video';

  @override
  String get cameraRecordStart => 'Start recording';

  @override
  String get cameraRecordStop => 'Stop recording';

  @override
  String get cameraRecording => 'Recording';

  @override
  String get cameraRecordingNoSound => 'No sound: microphone access is off';

  @override
  String get errorRecordingFailed => 'The video could not be recorded.';

  @override
  String get videoResultTitle => 'Video';

  @override
  String get videoSaveToGallery => 'Save to gallery';

  @override
  String get videoSavedToGallery => 'Saved to your gallery';

  @override
  String get videoSaveFailed => 'Could not save to the gallery. Check photo access in Settings.';

  @override
  String get videoNotFound => 'This video is no longer available.';

  @override
  String get videoPlay => 'Play';

  @override
  String get videoPause => 'Pause';

  @override
  String get videoEdit => 'Edit video';

  @override
  String get videoSilent => 'Recorded without sound';

  @override
  String get errorExportCancelled => 'Export cancelled.';

  @override
  String get videoEditorTitle => 'Edit video';

  @override
  String get videoExport => 'Export';

  @override
  String videoExporting(int percent) {
    return 'Exporting… $percent%';
  }

  @override
  String get videoExportFailed => 'The video could not be exported.';

  @override
  String get videoToolTrim => 'Trim';

  @override
  String get videoToolSpeed => 'Speed';

  @override
  String get videoToolLook => 'Look';

  @override
  String get videoToolText => 'Text';

  @override
  String get videoToolStickers => 'Stickers';

  @override
  String get videoToolMusic => 'Music';

  @override
  String get videoAddClip => 'Add clip';

  @override
  String get videoRemoveClip => 'Remove clip';

  @override
  String get videoSpeedMutes => 'Clips at another speed play without their own sound; music still plays.';

  @override
  String get videoApplyBeauty => 'Beauty on faces';

  @override
  String get videoApplyBeautyHint => 'Off keeps only the filter and sharpness.';

  @override
  String get videoLookPreview => 'Look preview (one frame)';

  @override
  String get videoAddText => 'Add text';

  @override
  String get videoTextDialogTitle => 'Text';

  @override
  String get videoTextHint => 'Your text';

  @override
  String get videoOverlayTime => 'Visible';

  @override
  String get videoOverlayDelete => 'Delete';

  @override
  String get videoOverlayHint => 'Tap an item to select it, drag to move, pinch to resize and rotate.';

  @override
  String get videoMusicPick => 'Choose';

  @override
  String get videoMusicNone => 'No music';

  @override
  String get videoMusicSelected => 'Music added (loops, fades out)';

  @override
  String get videoMusicRemove => 'Remove music';

  @override
  String get videoMusicVolume => 'Music';

  @override
  String get videoOriginalVolume => 'Clip sound';

  @override
  String get videoImportFailed => 'This video could not be imported.';

  @override
  String get projectsPhotosTab => 'Photos';

  @override
  String get projectsVideosTab => 'Videos';

  @override
  String get projectsNewVideo => 'New video';

  @override
  String get projectsVideoEmptyBody => 'Import a video or record one with the camera. Your original is never changed.';

  @override
  String get templatesTitle => 'Templates';

  @override
  String get templatesSave => 'Save';

  @override
  String get templatesSlotHint => 'Drag to move the photo, pinch to zoom.';

  @override
  String get templatesReplace => 'Replace';

  @override
  String get templatesBackground => 'Background';

  @override
  String get templatesSpacing => 'Spacing';

  @override
  String get templatesCorners => 'Corners';

  @override
  String get templatesCaptionHint => 'Caption (optional)';

  @override
  String get statusBlocked => 'Blocked';

  @override
  String featureBlockedBody(String feature) {
    return '$feature needs a generative AI model service (a paid API or GPU servers). It will be switched on once that service is approved. Nothing is charged until then.';
  }

  @override
  String get errorNetwork => 'No connection to the server. Check your internet and try again.';

  @override
  String get errorTimeout => 'The server took too long to answer. Try again.';

  @override
  String get errorSessionExpired => 'Your session has ended. Sign in again.';

  @override
  String get errorInvalidCredentials => 'Email or password is incorrect.';

  @override
  String get errorEmailTaken => 'An account with this email already exists.';

  @override
  String get errorRateLimited => 'Too many attempts. Wait a minute and try again.';

  @override
  String get errorInvalidPassword => 'The password is incorrect.';

  @override
  String get errorInsufficientCredits => 'Not enough credits for this.';

  @override
  String get errorConsentRequired => 'Allow cloud AI processing first.';

  @override
  String get errorAiUnavailable => 'This AI feature is not available on the server right now. No credits were charged.';

  @override
  String get errorUnsupportedImage => 'This photo format is not supported. Use JPEG or PNG.';

  @override
  String get errorImageTooLarge => 'The photo is too large.';

  @override
  String get errorNoPerson =>
      'No person was found in the photo. Choose one where a person is clearly visible. Your credits were refunded.';

  @override
  String get errorProcessingTimeout => 'Processing is taking longer than usual. Try again later.';

  @override
  String get errorJobCancelled => 'The job was cancelled. Your credits were refunded.';

  @override
  String get errorProcessingFailed => 'Processing failed. Your credits were refunded.';

  @override
  String get errorFile => 'The photo could not be read or saved on this device.';

  @override
  String get errorServer => 'The server had a problem. Try again later.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountUnconfiguredTitle => 'Accounts are not available in this build';

  @override
  String get accountUnconfiguredBody =>
      'This build is not connected to a Yuz server. The camera, editing and every on-device effect work without an account.';

  @override
  String get accountSignedOutBody => 'Sign in to use cloud AI features and keep your credits.';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get accountCreate => 'Create account';

  @override
  String get accountLoadFailed => 'Could not load your account.';

  @override
  String accountCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count credits', one: '1 credit');
    return '$_temp0';
  }

  @override
  String accountPremiumActive(String date) {
    return 'Premium until $date';
  }

  @override
  String get accountPremiumInactive => 'Premium is not active';

  @override
  String get accountStore => 'Credits & Premium';

  @override
  String get accountCloudAi => 'Cloud AI processing';

  @override
  String get accountCloudAiOn => 'Allowed. Photos you send to AI features are processed on Yuz servers.';

  @override
  String get accountCloudAiOff => 'Not allowed. Nothing is uploaded.';

  @override
  String get accountRevokeTitle => 'Stop cloud AI processing?';

  @override
  String get accountRevokeBody => 'Queued jobs are cancelled and refunded, and their uploaded photos are deleted.';

  @override
  String get accountRevokeConfirm => 'Stop';

  @override
  String get accountDisplayName => 'Display name';

  @override
  String get accountExport => 'Download my data';

  @override
  String get accountExportDone => 'Your data was saved.';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountDelete => 'Delete account';

  @override
  String get accountDeleteBody =>
      'This permanently deletes your account, credits, AI jobs and uploaded photos. Projects stored on this phone stay. Enter your password to confirm.';

  @override
  String get accountDeleteConfirm => 'Delete permanently';

  @override
  String get accountDeleted => 'Your account was deleted.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHint => 'At least 10 characters';

  @override
  String get authName => 'Name (optional)';

  @override
  String get authEmailInvalid => 'Enter a valid email';

  @override
  String get authPasswordShort => 'Use at least 10 characters';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authSwitchToRegister => 'No account yet? Create one';

  @override
  String get authSwitchToSignIn => 'Already have an account? Sign in';

  @override
  String get authSecurityNote =>
      'Your password travels only over an encrypted connection and is stored as a salted hash, never as text.';

  @override
  String get consentIntro =>
      'AI features such as background replacement run on Yuz servers. Before anything is uploaded, this is exactly what happens:';

  @override
  String get consentPointUpload =>
      'Only the photo you choose for an AI feature is uploaded, over an encrypted connection.';

  @override
  String get consentPointDelete =>
      'The uploaded photo is deleted from the server as soon as processing ends. The result is removed once it reaches your phone; anything left over is purged automatically.';

  @override
  String get consentPointUse =>
      'Photos are used only to make your result — never for advertising and never to train models.';

  @override
  String get consentPointPeople => 'Only upload photos of yourself or of people who agreed.';

  @override
  String get consentPointLocal =>
      'The beauty camera, retouch and filters keep working fully on your phone without this permission.';

  @override
  String get consentPointRevoke => 'You can withdraw this permission at any time in Account.';

  @override
  String get consentAccept => 'Allow cloud AI';

  @override
  String get consentDecline => 'Not now';

  @override
  String consentVersion(String version) {
    return 'Consent version $version';
  }

  @override
  String get storeBalance => 'Balance';

  @override
  String get storeBlockedTitle => 'Purchases are not enabled yet';

  @override
  String get storeBlockedBody =>
      'Buying credits and Premium needs App Store and Google Play products and their server-side verification to be set up. Until then nothing can be charged.';

  @override
  String storePremium(int days) {
    return 'Premium · $days days';
  }

  @override
  String get storeUnavailable => 'Unavailable';

  @override
  String get storePrices => 'AI prices';

  @override
  String get storeHistory => 'History';

  @override
  String get storeHistoryEmpty => 'No credit activity yet.';

  @override
  String get creditKindWelcome => 'Welcome bonus';

  @override
  String get creditKindPurchase => 'Purchase';

  @override
  String get creditKindSpend => 'AI processing';

  @override
  String get creditKindRefund => 'Refund';

  @override
  String get creditKindAdjustment => 'Adjustment';

  @override
  String get aiBgIntro => 'Blur, recolour or remove the background behind people. Processed on Yuz servers.';

  @override
  String get aiPickGallery => 'Choose photo';

  @override
  String get aiPickCamera => 'Take photo';

  @override
  String get aiPickHint => 'Choose a photo with a person';

  @override
  String get aiModeBlur => 'Blur';

  @override
  String get aiModeColor => 'Colour';

  @override
  String get aiModeRemove => 'Remove';

  @override
  String aiStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Process · $count credits',
      one: 'Process · 1 credit',
    );
    return '$_temp0';
  }

  @override
  String aiBalance(int count) {
    return 'Balance: $count';
  }

  @override
  String get aiStageUploading => 'Uploading…';

  @override
  String get aiStageQueued => 'Waiting in queue…';

  @override
  String get aiStageRunning => 'Processing…';

  @override
  String get aiStageDownloading => 'Downloading the result…';

  @override
  String get aiViewOriginal => 'Original';

  @override
  String get aiViewResult => 'Result';

  @override
  String get aiOpenEditor => 'Edit in Yuz';

  @override
  String get aiSignInRequired => 'Sign in to use AI background.';

  @override
  String get aiConsentRequired => 'Allow cloud AI processing to continue.';

  @override
  String get aiReviewConsent => 'Review and allow';

  @override
  String get aiPrivacyNote => 'Only this photo is uploaded. It is deleted from the server after processing.';

  @override
  String get helpIntro => 'Answers to common questions.';

  @override
  String get helpUploadQ => 'Are my photos uploaded?';

  @override
  String get helpUploadA =>
      'No. The beauty camera, retouch, filters, stickers, templates and the video editor run entirely on your phone. A photo leaves the phone only when you use a cloud AI feature, after you have allowed it.';

  @override
  String get helpCreditsQ => 'What are credits?';

  @override
  String get helpCreditsA =>
      'Cloud AI features use server computing time and cost credits. New accounts get free welcome credits. When processing fails, the credits are refunded automatically.';

  @override
  String get helpBlockedQ => 'Why are some AI features unavailable?';

  @override
  String get helpBlockedA =>
      'AI photoshoot, hairstyle and makeup need a generative model service that is not switched on yet. They are marked as blocked and never charge credits.';

  @override
  String get helpDeleteQ => 'How do I delete my data?';

  @override
  String get helpDeleteA =>
      'Projects are stored on your phone; delete them in Projects. Your account and everything on the server can be deleted in Account → Delete account. Download a copy first with “Download my data”.';

  @override
  String get helpCameraQ => 'The camera shows a black screen';

  @override
  String get helpCameraA =>
      'Check that camera access is allowed in the system settings, and close other apps that use the camera.';

  @override
  String get helpSavedQ => 'Where are my saved photos and videos?';

  @override
  String get helpSavedA =>
      'In your phone\'s gallery, in the “Yuz” album. Projects you have not exported stay inside the app.';
}
