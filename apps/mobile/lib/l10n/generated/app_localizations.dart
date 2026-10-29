import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('ru'), Locale('uz')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Yuz'**
  String get appTitle;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Beauty, processed on your device'**
  String get splashTagline;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get actionGetStarted;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get actionOpenSettings;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Real-time beauty camera'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In en, this message translates to:
  /// **'Natural skin smoothing that keeps your texture, rendered live on the GPU.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In en, this message translates to:
  /// **'Camera effects run entirely on your phone. Nothing is uploaded for on-device features.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Your look, your presets'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune every effect from 0 to 100 and save your favourite combinations.'**
  String get onboardingBody3;

  /// No description provided for @permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access'**
  String get permissionTitle;

  /// No description provided for @permissionBody.
  ///
  /// In en, this message translates to:
  /// **'Yuz needs the camera to show the live beauty preview and take photos. Frames stay on your device.'**
  String get permissionBody;

  /// No description provided for @permissionGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow camera'**
  String get permissionGrant;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access was denied. The camera features stay unavailable until you allow it.'**
  String get permissionDenied;

  /// No description provided for @permissionPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is blocked. Enable it for Yuz in system settings.'**
  String get permissionPermanentlyDenied;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Create your look'**
  String get homeGreeting;

  /// No description provided for @homeSectionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get homeSectionCamera;

  /// No description provided for @homeSectionEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get homeSectionEditing;

  /// No description provided for @homeSectionAi.
  ///
  /// In en, this message translates to:
  /// **'AI studio'**
  String get homeSectionAi;

  /// No description provided for @homeSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get homeSectionAccount;

  /// No description provided for @featureBeautyCamera.
  ///
  /// In en, this message translates to:
  /// **'Beauty camera'**
  String get featureBeautyCamera;

  /// No description provided for @featureBeautyCameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Live skin smoothing'**
  String get featureBeautyCameraSubtitle;

  /// No description provided for @featurePhotoEditor.
  ///
  /// In en, this message translates to:
  /// **'Photo editor'**
  String get featurePhotoEditor;

  /// No description provided for @featureVideoEditor.
  ///
  /// In en, this message translates to:
  /// **'Video editor'**
  String get featureVideoEditor;

  /// No description provided for @featureAiPhotoshoot.
  ///
  /// In en, this message translates to:
  /// **'AI photoshoot'**
  String get featureAiPhotoshoot;

  /// No description provided for @featureAiHairstyle.
  ///
  /// In en, this message translates to:
  /// **'AI hairstyle'**
  String get featureAiHairstyle;

  /// No description provided for @featureAiMakeup.
  ///
  /// In en, this message translates to:
  /// **'AI makeup'**
  String get featureAiMakeup;

  /// No description provided for @featureAiBackground.
  ///
  /// In en, this message translates to:
  /// **'AI background'**
  String get featureAiBackground;

  /// No description provided for @featureTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get featureTemplates;

  /// No description provided for @featureProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get featureProjects;

  /// No description provided for @featurePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get featurePremium;

  /// No description provided for @featureCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get featureCredits;

  /// No description provided for @featureProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get featureProfile;

  /// No description provided for @featureSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get featureSettings;

  /// No description provided for @featureHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get featureHelp;

  /// No description provided for @statusImplemented.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get statusImplemented;

  /// No description provided for @statusPartial.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get statusPartial;

  /// No description provided for @statusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get statusNotStarted;

  /// No description provided for @featureUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get featureUnavailableTitle;

  /// No description provided for @featureUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'{feature} is planned for development phase {phase}. It is not part of this build.'**
  String featureUnavailableBody(String feature, int phase);

  /// No description provided for @beautyReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get beautyReset;

  /// No description provided for @beautyUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get beautyUndo;

  /// No description provided for @beautySavePreset.
  ///
  /// In en, this message translates to:
  /// **'Save preset'**
  String get beautySavePreset;

  /// No description provided for @beautyPresetNameHint.
  ///
  /// In en, this message translates to:
  /// **'Preset name'**
  String get beautyPresetNameHint;

  /// No description provided for @beautyPresets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get beautyPresets;

  /// No description provided for @beautyPresetNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get beautyPresetNatural;

  /// No description provided for @beautyPresetSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get beautyPresetSoft;

  /// No description provided for @beautyPresetGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get beautyPresetGlow;

  /// No description provided for @beautyPresetSaved.
  ///
  /// In en, this message translates to:
  /// **'Preset “{name}” saved'**
  String beautyPresetSaved(String name);

  /// No description provided for @cameraSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get cameraSwitch;

  /// No description provided for @cameraCapture.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get cameraCapture;

  /// No description provided for @cameraTimer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get cameraTimer;

  /// No description provided for @cameraTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Timer off'**
  String get cameraTimerOff;

  /// No description provided for @cameraTimerSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String cameraTimerSeconds(int seconds);

  /// No description provided for @cameraFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash'**
  String get cameraFlash;

  /// No description provided for @cameraFlashOff.
  ///
  /// In en, this message translates to:
  /// **'Flash off'**
  String get cameraFlashOff;

  /// No description provided for @cameraFlashAuto.
  ///
  /// In en, this message translates to:
  /// **'Flash auto'**
  String get cameraFlashAuto;

  /// No description provided for @cameraFlashOn.
  ///
  /// In en, this message translates to:
  /// **'Flash on'**
  String get cameraFlashOn;

  /// No description provided for @cameraFlashTorch.
  ///
  /// In en, this message translates to:
  /// **'Torch'**
  String get cameraFlashTorch;

  /// No description provided for @cameraZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get cameraZoom;

  /// No description provided for @cameraExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get cameraExposure;

  /// No description provided for @cameraNoFace.
  ///
  /// In en, this message translates to:
  /// **'No face detected'**
  String get cameraNoFace;

  /// No description provided for @cameraFacesDetected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 face} other{{count} faces}}'**
  String cameraFacesDetected(int count);

  /// No description provided for @cameraTrackingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Face tracking unavailable — skin tone detection only'**
  String get cameraTrackingUnavailable;

  /// No description provided for @cameraStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting camera…'**
  String get cameraStarting;

  /// No description provided for @cameraMeasuredFps.
  ///
  /// In en, this message translates to:
  /// **'{fps} FPS · GPU {gpu} ms · face {detector} ms'**
  String cameraMeasuredFps(String fps, String gpu, String detector);

  /// No description provided for @cameraPhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo saved'**
  String get cameraPhotoSaved;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required.'**
  String get errorPermissionDenied;

  /// No description provided for @errorCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera is not available on this device right now.'**
  String get errorCameraUnavailable;

  /// No description provided for @errorCameraInUse.
  ///
  /// In en, this message translates to:
  /// **'Another app is using the camera.'**
  String get errorCameraInUse;

  /// No description provided for @errorCameraDisconnected.
  ///
  /// In en, this message translates to:
  /// **'The camera was disconnected.'**
  String get errorCameraDisconnected;

  /// No description provided for @errorGpu.
  ///
  /// In en, this message translates to:
  /// **'This device\'s GPU could not start the beauty engine.'**
  String get errorGpu;

  /// No description provided for @errorCaptureFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be saved.'**
  String get errorCaptureFailed;

  /// No description provided for @errorThermal.
  ///
  /// In en, this message translates to:
  /// **'The phone is hot — face tracking is paused to cool down.'**
  String get errorThermal;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorUnknown;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsPerformanceOverlay.
  ///
  /// In en, this message translates to:
  /// **'Show measured performance'**
  String get settingsPerformanceOverlay;

  /// No description provided for @settingsPerformanceOverlaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'FPS, GPU and face-tracking timings measured on device'**
  String get settingsPerformanceOverlaySubtitle;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsResetOnboarding.
  ///
  /// In en, this message translates to:
  /// **'Show onboarding again'**
  String get settingsResetOnboarding;

  /// No description provided for @languageUzbek.
  ///
  /// In en, this message translates to:
  /// **'Oʻzbekcha'**
  String get languageUzbek;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @privacyOnDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'On-device processing'**
  String get privacyOnDeviceTitle;

  /// No description provided for @privacyOnDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Live camera effects, skin smoothing and face tracking run on your phone. These features never send images to a server.'**
  String get privacyOnDeviceBody;

  /// No description provided for @privacyStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'What is stored'**
  String get privacyStorageTitle;

  /// No description provided for @privacyStorageBody.
  ///
  /// In en, this message translates to:
  /// **'Photos you take are saved in the app\'s private storage. Your settings and beauty presets are stored locally.'**
  String get privacyStorageBody;

  /// No description provided for @privacyCloudTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI features'**
  String get privacyCloudTitle;

  /// No description provided for @privacyCloudBody.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI features ask for your explicit consent before any photo is uploaded. Only the photo you choose is sent, over an encrypted connection; it is deleted from the server after processing and never used for advertising or model training. You can withdraw consent in Account.'**
  String get privacyCloudBody;

  /// No description provided for @privacyDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting your data'**
  String get privacyDeletionTitle;

  /// No description provided for @privacyDeletionBody.
  ///
  /// In en, this message translates to:
  /// **'Uninstalling the app removes all locally stored photos, presets and settings. Your account and everything stored on the server can be deleted in Account.'**
  String get privacyDeletionBody;

  /// No description provided for @tabLooks.
  ///
  /// In en, this message translates to:
  /// **'Looks'**
  String get tabLooks;

  /// No description provided for @tabFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get tabFilters;

  /// No description provided for @tabSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get tabSkin;

  /// No description provided for @tabFace.
  ///
  /// In en, this message translates to:
  /// **'Face'**
  String get tabFace;

  /// No description provided for @tabReshape.
  ///
  /// In en, this message translates to:
  /// **'Reshape'**
  String get tabReshape;

  /// No description provided for @tabMakeup.
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get tabMakeup;

  /// No description provided for @tabCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get tabCamera;

  /// No description provided for @effectSkinSmoothing.
  ///
  /// In en, this message translates to:
  /// **'Smooth'**
  String get effectSkinSmoothing;

  /// No description provided for @effectTexturePreservation.
  ///
  /// In en, this message translates to:
  /// **'Texture'**
  String get effectTexturePreservation;

  /// No description provided for @effectSkinBrightening.
  ///
  /// In en, this message translates to:
  /// **'Brighten'**
  String get effectSkinBrightening;

  /// No description provided for @effectSkinTone.
  ///
  /// In en, this message translates to:
  /// **'Even tone'**
  String get effectSkinTone;

  /// No description provided for @effectBlemishReduction.
  ///
  /// In en, this message translates to:
  /// **'Blemishes'**
  String get effectBlemishReduction;

  /// No description provided for @effectShineReduction.
  ///
  /// In en, this message translates to:
  /// **'Matte'**
  String get effectShineReduction;

  /// No description provided for @effectGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get effectGlow;

  /// No description provided for @effectEyeBrightening.
  ///
  /// In en, this message translates to:
  /// **'Bright eyes'**
  String get effectEyeBrightening;

  /// No description provided for @effectTeethWhitening.
  ///
  /// In en, this message translates to:
  /// **'Teeth'**
  String get effectTeethWhitening;

  /// No description provided for @effectDarkCircles.
  ///
  /// In en, this message translates to:
  /// **'Dark circles'**
  String get effectDarkCircles;

  /// No description provided for @effectFaceSlim.
  ///
  /// In en, this message translates to:
  /// **'Slim face'**
  String get effectFaceSlim;

  /// No description provided for @effectJawline.
  ///
  /// In en, this message translates to:
  /// **'Jawline'**
  String get effectJawline;

  /// No description provided for @effectChin.
  ///
  /// In en, this message translates to:
  /// **'Chin'**
  String get effectChin;

  /// No description provided for @effectEyeEnlarge.
  ///
  /// In en, this message translates to:
  /// **'Bigger eyes'**
  String get effectEyeEnlarge;

  /// No description provided for @effectNoseSlim.
  ///
  /// In en, this message translates to:
  /// **'Nose'**
  String get effectNoseSlim;

  /// No description provided for @effectLips.
  ///
  /// In en, this message translates to:
  /// **'Fuller lips'**
  String get effectLips;

  /// No description provided for @effectForehead.
  ///
  /// In en, this message translates to:
  /// **'Forehead'**
  String get effectForehead;

  /// No description provided for @effectLipstick.
  ///
  /// In en, this message translates to:
  /// **'Lipstick'**
  String get effectLipstick;

  /// No description provided for @effectBlush.
  ///
  /// In en, this message translates to:
  /// **'Blush'**
  String get effectBlush;

  /// No description provided for @effectEyebrows.
  ///
  /// In en, this message translates to:
  /// **'Brows'**
  String get effectEyebrows;

  /// No description provided for @effectEyeshadow.
  ///
  /// In en, this message translates to:
  /// **'Eyeshadow'**
  String get effectEyeshadow;

  /// No description provided for @effectEyeliner.
  ///
  /// In en, this message translates to:
  /// **'Eyeliner'**
  String get effectEyeliner;

  /// No description provided for @effectMakeupIntensity.
  ///
  /// In en, this message translates to:
  /// **'Makeup'**
  String get effectMakeupIntensity;

  /// No description provided for @effectFilterIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get effectFilterIntensity;

  /// No description provided for @filterNone.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get filterNone;

  /// No description provided for @filterNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural'**
  String get filterNatural;

  /// No description provided for @filterSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get filterSoft;

  /// No description provided for @filterGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get filterGlow;

  /// No description provided for @filterPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get filterPortrait;

  /// No description provided for @filterCinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get filterCinematic;

  /// No description provided for @filterWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get filterWarm;

  /// No description provided for @filterCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get filterCool;

  /// No description provided for @filterVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get filterVintage;

  /// No description provided for @filterBlackWhite.
  ///
  /// In en, this message translates to:
  /// **'B&W'**
  String get filterBlackWhite;

  /// No description provided for @filterCustom.
  ///
  /// In en, this message translates to:
  /// **'My LUT'**
  String get filterCustom;

  /// No description provided for @filterImport.
  ///
  /// In en, this message translates to:
  /// **'Import LUT'**
  String get filterImport;

  /// No description provided for @lutImported.
  ///
  /// In en, this message translates to:
  /// **'Custom LUT imported'**
  String get lutImported;

  /// No description provided for @lutImportWrongSize.
  ///
  /// In en, this message translates to:
  /// **'A LUT image must be 512×512 pixels.'**
  String get lutImportWrongSize;

  /// No description provided for @lutImportUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This image could not be read.'**
  String get lutImportUnreadable;

  /// No description provided for @beautyPresetEverydayMakeup.
  ///
  /// In en, this message translates to:
  /// **'Everyday'**
  String get beautyPresetEverydayMakeup;

  /// No description provided for @beautyPresetEveningMakeup.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get beautyPresetEveningMakeup;

  /// No description provided for @requiresFaceTracking.
  ///
  /// In en, this message translates to:
  /// **'Needs face tracking — face the camera'**
  String get requiresFaceTracking;

  /// No description provided for @makeupShade.
  ///
  /// In en, this message translates to:
  /// **'Shade'**
  String get makeupShade;

  /// No description provided for @effectSharpen.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get effectSharpen;

  /// No description provided for @projectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @projectsNew.
  ///
  /// In en, this message translates to:
  /// **'New photo'**
  String get projectsNew;

  /// No description provided for @projectsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get projectsEmptyTitle;

  /// No description provided for @projectsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import a photo to retouch it. Your original is never changed.'**
  String get projectsEmptyBody;

  /// No description provided for @projectsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete project?'**
  String get projectsDeleteTitle;

  /// No description provided for @projectsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The copy, edits and exports stored in the app are removed. Photos already saved to your gallery stay.'**
  String get projectsDeleteBody;

  /// No description provided for @projectsImportFailed.
  ///
  /// In en, this message translates to:
  /// **'This file could not be imported.'**
  String get projectsImportFailed;

  /// No description provided for @photoRetouchTitle.
  ///
  /// In en, this message translates to:
  /// **'Retouch'**
  String get photoRetouchTitle;

  /// No description provided for @photoNext.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get photoNext;

  /// No description provided for @photoCompare.
  ///
  /// In en, this message translates to:
  /// **'Hold to compare'**
  String get photoCompare;

  /// No description provided for @photoPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing full-resolution image…'**
  String get photoPreparing;

  /// No description provided for @photoNotFound.
  ///
  /// In en, this message translates to:
  /// **'This project no longer exists.'**
  String get photoNotFound;

  /// No description provided for @photoRenderFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be processed.'**
  String get photoRenderFailed;

  /// No description provided for @photoSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery'**
  String get photoSavedToGallery;

  /// No description provided for @photoSavedInApp.
  ///
  /// In en, this message translates to:
  /// **'Saved in Yuz (no gallery access)'**
  String get photoSavedInApp;

  /// No description provided for @photoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The edit could not be saved.'**
  String get photoSaveFailed;

  /// No description provided for @editorPaint.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get editorPaint;

  /// No description provided for @editorText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get editorText;

  /// No description provided for @editorCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get editorCrop;

  /// No description provided for @editorTune.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get editorTune;

  /// No description provided for @editorBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get editorBlur;

  /// No description provided for @editorEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get editorEmoji;

  /// No description provided for @editorStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get editorStickers;

  /// No description provided for @editorBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get editorBrightness;

  /// No description provided for @editorContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get editorContrast;

  /// No description provided for @editorSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get editorSaturation;

  /// No description provided for @editorExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get editorExposure;

  /// No description provided for @editorHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get editorHue;

  /// No description provided for @editorTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get editorTemperature;

  /// No description provided for @editorFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get editorFade;

  /// No description provided for @editorTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get editorTint;

  /// No description provided for @editorRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get editorRotate;

  /// No description provided for @editorFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get editorFlip;

  /// No description provided for @editorRatio.
  ///
  /// In en, this message translates to:
  /// **'Ratio'**
  String get editorRatio;

  /// No description provided for @editorReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get editorReset;

  /// No description provided for @editorTextHint.
  ///
  /// In en, this message translates to:
  /// **'Enter text'**
  String get editorTextHint;

  /// No description provided for @editorDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editorDone;

  /// No description provided for @editorBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get editorBack;

  /// No description provided for @editorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get editorUndo;

  /// No description provided for @editorRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get editorRedo;

  /// No description provided for @editorRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get editorRemove;

  /// No description provided for @editorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editorEdit;

  /// No description provided for @editorApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying changes…'**
  String get editorApplying;

  /// No description provided for @editorLoading.
  ///
  /// In en, this message translates to:
  /// **'Please wait…'**
  String get editorLoading;

  /// No description provided for @editorCloseTitle.
  ///
  /// In en, this message translates to:
  /// **'Close the editor?'**
  String get editorCloseTitle;

  /// No description provided for @editorCloseBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits are kept in the project.'**
  String get editorCloseBody;

  /// No description provided for @editorEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get editorEraser;

  /// No description provided for @editorLineWidth.
  ///
  /// In en, this message translates to:
  /// **'Line width'**
  String get editorLineWidth;

  /// No description provided for @editorOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get editorOpacity;

  /// No description provided for @editorColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get editorColor;

  /// No description provided for @editorSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get editorSearch;

  /// No description provided for @editorAlign.
  ///
  /// In en, this message translates to:
  /// **'Align text'**
  String get editorAlign;

  /// No description provided for @editorRotateScale.
  ///
  /// In en, this message translates to:
  /// **'Rotate and scale'**
  String get editorRotateScale;

  /// No description provided for @cameraModePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get cameraModePhoto;

  /// No description provided for @cameraModeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get cameraModeVideo;

  /// No description provided for @cameraRecordStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get cameraRecordStart;

  /// No description provided for @cameraRecordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get cameraRecordStop;

  /// No description provided for @cameraRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get cameraRecording;

  /// No description provided for @cameraRecordingNoSound.
  ///
  /// In en, this message translates to:
  /// **'No sound: microphone access is off'**
  String get cameraRecordingNoSound;

  /// No description provided for @errorRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'The video could not be recorded.'**
  String get errorRecordingFailed;

  /// No description provided for @videoResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoResultTitle;

  /// No description provided for @videoSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get videoSaveToGallery;

  /// No description provided for @videoSavedToGallery.
  ///
  /// In en, this message translates to:
  /// **'Saved to your gallery'**
  String get videoSavedToGallery;

  /// No description provided for @videoSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save to the gallery. Check photo access in Settings.'**
  String get videoSaveFailed;

  /// No description provided for @videoNotFound.
  ///
  /// In en, this message translates to:
  /// **'This video is no longer available.'**
  String get videoNotFound;

  /// No description provided for @videoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoPlay;

  /// No description provided for @videoPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get videoPause;

  /// No description provided for @videoEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get videoEdit;

  /// No description provided for @videoSilent.
  ///
  /// In en, this message translates to:
  /// **'Recorded without sound'**
  String get videoSilent;

  /// No description provided for @errorExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Export cancelled.'**
  String get errorExportCancelled;

  /// No description provided for @videoEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get videoEditorTitle;

  /// No description provided for @videoExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get videoExport;

  /// No description provided for @videoExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting… {percent}%'**
  String videoExporting(int percent);

  /// No description provided for @videoExportFailed.
  ///
  /// In en, this message translates to:
  /// **'The video could not be exported.'**
  String get videoExportFailed;

  /// No description provided for @videoToolTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get videoToolTrim;

  /// No description provided for @videoToolSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get videoToolSpeed;

  /// No description provided for @videoToolLook.
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get videoToolLook;

  /// No description provided for @videoToolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get videoToolText;

  /// No description provided for @videoToolStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get videoToolStickers;

  /// No description provided for @videoToolMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get videoToolMusic;

  /// No description provided for @videoAddClip.
  ///
  /// In en, this message translates to:
  /// **'Add clip'**
  String get videoAddClip;

  /// No description provided for @videoRemoveClip.
  ///
  /// In en, this message translates to:
  /// **'Remove clip'**
  String get videoRemoveClip;

  /// No description provided for @videoSpeedMutes.
  ///
  /// In en, this message translates to:
  /// **'Clips at another speed play without their own sound; music still plays.'**
  String get videoSpeedMutes;

  /// No description provided for @videoApplyBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty on faces'**
  String get videoApplyBeauty;

  /// No description provided for @videoApplyBeautyHint.
  ///
  /// In en, this message translates to:
  /// **'Off keeps only the filter and sharpness.'**
  String get videoApplyBeautyHint;

  /// No description provided for @videoLookPreview.
  ///
  /// In en, this message translates to:
  /// **'Look preview (one frame)'**
  String get videoLookPreview;

  /// No description provided for @videoAddText.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get videoAddText;

  /// No description provided for @videoTextDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get videoTextDialogTitle;

  /// No description provided for @videoTextHint.
  ///
  /// In en, this message translates to:
  /// **'Your text'**
  String get videoTextHint;

  /// No description provided for @videoOverlayTime.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get videoOverlayTime;

  /// No description provided for @videoOverlayDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get videoOverlayDelete;

  /// No description provided for @videoOverlayHint.
  ///
  /// In en, this message translates to:
  /// **'Tap an item to select it, drag to move, pinch to resize and rotate.'**
  String get videoOverlayHint;

  /// No description provided for @videoMusicPick.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get videoMusicPick;

  /// No description provided for @videoMusicNone.
  ///
  /// In en, this message translates to:
  /// **'No music'**
  String get videoMusicNone;

  /// No description provided for @videoMusicSelected.
  ///
  /// In en, this message translates to:
  /// **'Music added (loops, fades out)'**
  String get videoMusicSelected;

  /// No description provided for @videoMusicRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove music'**
  String get videoMusicRemove;

  /// No description provided for @videoMusicVolume.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get videoMusicVolume;

  /// No description provided for @videoOriginalVolume.
  ///
  /// In en, this message translates to:
  /// **'Clip sound'**
  String get videoOriginalVolume;

  /// No description provided for @videoImportFailed.
  ///
  /// In en, this message translates to:
  /// **'This video could not be imported.'**
  String get videoImportFailed;

  /// No description provided for @projectsPhotosTab.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get projectsPhotosTab;

  /// No description provided for @projectsVideosTab.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get projectsVideosTab;

  /// No description provided for @projectsNewVideo.
  ///
  /// In en, this message translates to:
  /// **'New video'**
  String get projectsNewVideo;

  /// No description provided for @projectsVideoEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import a video or record one with the camera. Your original is never changed.'**
  String get projectsVideoEmptyBody;

  /// No description provided for @templatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templatesTitle;

  /// No description provided for @templatesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get templatesSave;

  /// No description provided for @templatesSlotHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move the photo, pinch to zoom.'**
  String get templatesSlotHint;

  /// No description provided for @templatesReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get templatesReplace;

  /// No description provided for @templatesBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get templatesBackground;

  /// No description provided for @templatesSpacing.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get templatesSpacing;

  /// No description provided for @templatesCorners.
  ///
  /// In en, this message translates to:
  /// **'Corners'**
  String get templatesCorners;

  /// No description provided for @templatesCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Caption (optional)'**
  String get templatesCaptionHint;

  /// No description provided for @statusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get statusBlocked;

  /// No description provided for @featureBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'{feature} needs a generative AI model service (a paid API or GPU servers). It will be switched on once that service is approved. Nothing is charged until then.'**
  String featureBlockedBody(String feature);

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server. Check your internet and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server took too long to answer. Try again.'**
  String get errorTimeout;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get errorEmailTaken;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect.'**
  String get errorInvalidPassword;

  /// No description provided for @errorInsufficientCredits.
  ///
  /// In en, this message translates to:
  /// **'Not enough credits for this.'**
  String get errorInsufficientCredits;

  /// No description provided for @errorConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow cloud AI processing first.'**
  String get errorConsentRequired;

  /// No description provided for @errorAiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This AI feature is not available on the server right now. No credits were charged.'**
  String get errorAiUnavailable;

  /// No description provided for @errorUnsupportedImage.
  ///
  /// In en, this message translates to:
  /// **'This photo format is not supported. Use JPEG or PNG.'**
  String get errorUnsupportedImage;

  /// No description provided for @errorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The photo is too large.'**
  String get errorImageTooLarge;

  /// No description provided for @errorNoPerson.
  ///
  /// In en, this message translates to:
  /// **'No person was found in the photo. Choose one where a person is clearly visible. Your credits were refunded.'**
  String get errorNoPerson;

  /// No description provided for @errorProcessingTimeout.
  ///
  /// In en, this message translates to:
  /// **'Processing is taking longer than usual. Try again later.'**
  String get errorProcessingTimeout;

  /// No description provided for @errorJobCancelled.
  ///
  /// In en, this message translates to:
  /// **'The job was cancelled. Your credits were refunded.'**
  String get errorJobCancelled;

  /// No description provided for @errorProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing failed. Your credits were refunded.'**
  String get errorProcessingFailed;

  /// No description provided for @errorFile.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be read or saved on this device.'**
  String get errorFile;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem. Try again later.'**
  String get errorServer;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountUnconfiguredTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts are not available in this build'**
  String get accountUnconfiguredTitle;

  /// No description provided for @accountUnconfiguredBody.
  ///
  /// In en, this message translates to:
  /// **'This build is not connected to a Yuz server. The camera, editing and every on-device effect work without an account.'**
  String get accountUnconfiguredBody;

  /// No description provided for @accountSignedOutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use cloud AI features and keep your credits.'**
  String get accountSignedOutBody;

  /// No description provided for @accountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountSignIn;

  /// No description provided for @accountCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountCreate;

  /// No description provided for @accountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your account.'**
  String get accountLoadFailed;

  /// No description provided for @accountCredits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 credit} other{{count} credits}}'**
  String accountCredits(int count);

  /// No description provided for @accountPremiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium until {date}'**
  String accountPremiumActive(String date);

  /// No description provided for @accountPremiumInactive.
  ///
  /// In en, this message translates to:
  /// **'Premium is not active'**
  String get accountPremiumInactive;

  /// No description provided for @accountStore.
  ///
  /// In en, this message translates to:
  /// **'Credits & Premium'**
  String get accountStore;

  /// No description provided for @accountCloudAi.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI processing'**
  String get accountCloudAi;

  /// No description provided for @accountCloudAiOn.
  ///
  /// In en, this message translates to:
  /// **'Allowed. Photos you send to AI features are processed on Yuz servers.'**
  String get accountCloudAiOn;

  /// No description provided for @accountCloudAiOff.
  ///
  /// In en, this message translates to:
  /// **'Not allowed. Nothing is uploaded.'**
  String get accountCloudAiOff;

  /// No description provided for @accountRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop cloud AI processing?'**
  String get accountRevokeTitle;

  /// No description provided for @accountRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'Queued jobs are cancelled and refunded, and their uploaded photos are deleted.'**
  String get accountRevokeBody;

  /// No description provided for @accountRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get accountRevokeConfirm;

  /// No description provided for @accountDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get accountDisplayName;

  /// No description provided for @accountExport.
  ///
  /// In en, this message translates to:
  /// **'Download my data'**
  String get accountExport;

  /// No description provided for @accountExportDone.
  ///
  /// In en, this message translates to:
  /// **'Your data was saved.'**
  String get accountExportDone;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDelete;

  /// No description provided for @accountDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, credits, AI jobs and uploaded photos. Projects stored on this phone stay. Enter your password to confirm.'**
  String get accountDeleteBody;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get accountDeleteConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get accountDeleted;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters'**
  String get authPasswordHint;

  /// No description provided for @authName.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get authName;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 10 characters'**
  String get authPasswordShort;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordRequired;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authSwitchToRegister.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get authSwitchToRegister;

  /// No description provided for @authSwitchToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authSwitchToSignIn;

  /// No description provided for @authSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'Your password travels only over an encrypted connection and is stored as a salted hash, never as text.'**
  String get authSecurityNote;

  /// No description provided for @consentIntro.
  ///
  /// In en, this message translates to:
  /// **'AI features such as background replacement run on Yuz servers. Before anything is uploaded, this is exactly what happens:'**
  String get consentIntro;

  /// No description provided for @consentPointUpload.
  ///
  /// In en, this message translates to:
  /// **'Only the photo you choose for an AI feature is uploaded, over an encrypted connection.'**
  String get consentPointUpload;

  /// No description provided for @consentPointDelete.
  ///
  /// In en, this message translates to:
  /// **'The uploaded photo is deleted from the server as soon as processing ends. The result is removed once it reaches your phone; anything left over is purged automatically.'**
  String get consentPointDelete;

  /// No description provided for @consentPointUse.
  ///
  /// In en, this message translates to:
  /// **'Photos are used only to make your result — never for advertising and never to train models.'**
  String get consentPointUse;

  /// No description provided for @consentPointPeople.
  ///
  /// In en, this message translates to:
  /// **'Only upload photos of yourself or of people who agreed.'**
  String get consentPointPeople;

  /// No description provided for @consentPointLocal.
  ///
  /// In en, this message translates to:
  /// **'The beauty camera, retouch and filters keep working fully on your phone without this permission.'**
  String get consentPointLocal;

  /// No description provided for @consentPointRevoke.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw this permission at any time in Account.'**
  String get consentPointRevoke;

  /// No description provided for @consentAccept.
  ///
  /// In en, this message translates to:
  /// **'Allow cloud AI'**
  String get consentAccept;

  /// No description provided for @consentDecline.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get consentDecline;

  /// No description provided for @consentVersion.
  ///
  /// In en, this message translates to:
  /// **'Consent version {version}'**
  String consentVersion(String version);

  /// No description provided for @storeBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get storeBalance;

  /// No description provided for @storeBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases are not enabled yet'**
  String get storeBlockedTitle;

  /// No description provided for @storeBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Buying credits and Premium needs App Store and Google Play products and their server-side verification to be set up. Until then nothing can be charged.'**
  String get storeBlockedBody;

  /// No description provided for @storePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium · {days} days'**
  String storePremium(int days);

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get storeUnavailable;

  /// No description provided for @storePrices.
  ///
  /// In en, this message translates to:
  /// **'AI prices'**
  String get storePrices;

  /// No description provided for @storeHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get storeHistory;

  /// No description provided for @storeHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No credit activity yet.'**
  String get storeHistoryEmpty;

  /// No description provided for @creditKindWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome bonus'**
  String get creditKindWelcome;

  /// No description provided for @creditKindPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get creditKindPurchase;

  /// No description provided for @creditKindSpend.
  ///
  /// In en, this message translates to:
  /// **'AI processing'**
  String get creditKindSpend;

  /// No description provided for @creditKindRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get creditKindRefund;

  /// No description provided for @creditKindAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get creditKindAdjustment;

  /// No description provided for @aiBgIntro.
  ///
  /// In en, this message translates to:
  /// **'Blur, recolour or remove the background behind people. Processed on Yuz servers.'**
  String get aiBgIntro;

  /// No description provided for @aiPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get aiPickGallery;

  /// No description provided for @aiPickCamera.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get aiPickCamera;

  /// No description provided for @aiPickHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo with a person'**
  String get aiPickHint;

  /// No description provided for @aiModeBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get aiModeBlur;

  /// No description provided for @aiModeColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get aiModeColor;

  /// No description provided for @aiModeRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get aiModeRemove;

  /// No description provided for @aiStart.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Process · 1 credit} other{Process · {count} credits}}'**
  String aiStart(int count);

  /// No description provided for @aiBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance: {count}'**
  String aiBalance(int count);

  /// No description provided for @aiStageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get aiStageUploading;

  /// No description provided for @aiStageQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting in queue…'**
  String get aiStageQueued;

  /// No description provided for @aiStageRunning.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get aiStageRunning;

  /// No description provided for @aiStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading the result…'**
  String get aiStageDownloading;

  /// No description provided for @aiViewOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get aiViewOriginal;

  /// No description provided for @aiViewResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get aiViewResult;

  /// No description provided for @aiOpenEditor.
  ///
  /// In en, this message translates to:
  /// **'Edit in Yuz'**
  String get aiOpenEditor;

  /// No description provided for @aiSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use AI background.'**
  String get aiSignInRequired;

  /// No description provided for @aiConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Allow cloud AI processing to continue.'**
  String get aiConsentRequired;

  /// No description provided for @aiReviewConsent.
  ///
  /// In en, this message translates to:
  /// **'Review and allow'**
  String get aiReviewConsent;

  /// No description provided for @aiPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Only this photo is uploaded. It is deleted from the server after processing.'**
  String get aiPrivacyNote;

  /// No description provided for @helpIntro.
  ///
  /// In en, this message translates to:
  /// **'Answers to common questions.'**
  String get helpIntro;

  /// No description provided for @helpUploadQ.
  ///
  /// In en, this message translates to:
  /// **'Are my photos uploaded?'**
  String get helpUploadQ;

  /// No description provided for @helpUploadA.
  ///
  /// In en, this message translates to:
  /// **'No. The beauty camera, retouch, filters, stickers, templates and the video editor run entirely on your phone. A photo leaves the phone only when you use a cloud AI feature, after you have allowed it.'**
  String get helpUploadA;

  /// No description provided for @helpCreditsQ.
  ///
  /// In en, this message translates to:
  /// **'What are credits?'**
  String get helpCreditsQ;

  /// No description provided for @helpCreditsA.
  ///
  /// In en, this message translates to:
  /// **'Cloud AI features use server computing time and cost credits. New accounts get free welcome credits. When processing fails, the credits are refunded automatically.'**
  String get helpCreditsA;

  /// No description provided for @helpBlockedQ.
  ///
  /// In en, this message translates to:
  /// **'Why are some AI features unavailable?'**
  String get helpBlockedQ;

  /// No description provided for @helpBlockedA.
  ///
  /// In en, this message translates to:
  /// **'AI photoshoot, hairstyle and makeup need a generative model service that is not switched on yet. They are marked as blocked and never charge credits.'**
  String get helpBlockedA;

  /// No description provided for @helpDeleteQ.
  ///
  /// In en, this message translates to:
  /// **'How do I delete my data?'**
  String get helpDeleteQ;

  /// No description provided for @helpDeleteA.
  ///
  /// In en, this message translates to:
  /// **'Projects are stored on your phone; delete them in Projects. Your account and everything on the server can be deleted in Account → Delete account. Download a copy first with “Download my data”.'**
  String get helpDeleteA;

  /// No description provided for @helpCameraQ.
  ///
  /// In en, this message translates to:
  /// **'The camera shows a black screen'**
  String get helpCameraQ;

  /// No description provided for @helpCameraA.
  ///
  /// In en, this message translates to:
  /// **'Check that camera access is allowed in the system settings, and close other apps that use the camera.'**
  String get helpCameraA;

  /// No description provided for @helpSavedQ.
  ///
  /// In en, this message translates to:
  /// **'Where are my saved photos and videos?'**
  String get helpSavedQ;

  /// No description provided for @helpSavedA.
  ///
  /// In en, this message translates to:
  /// **'In your phone\'s gallery, in the “Yuz” album. Projects you have not exported stay inside the app.'**
  String get helpSavedA;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
