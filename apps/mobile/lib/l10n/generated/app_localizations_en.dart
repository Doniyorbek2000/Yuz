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
      'Future cloud AI features will ask for your explicit consent before any photo is uploaded, and only for photos of yourself or people who agreed.';

  @override
  String get privacyDeletionTitle => 'Deleting your data';

  @override
  String get privacyDeletionBody => 'Uninstalling the app removes all locally stored photos, presets and settings.';

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
}
