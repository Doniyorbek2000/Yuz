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
  /// **'Future cloud AI features will ask for your explicit consent before any photo is uploaded, and only for photos of yourself or people who agreed.'**
  String get privacyCloudBody;

  /// No description provided for @privacyDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleting your data'**
  String get privacyDeletionTitle;

  /// No description provided for @privacyDeletionBody.
  ///
  /// In en, this message translates to:
  /// **'Uninstalling the app removes all locally stored photos, presets and settings.'**
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
