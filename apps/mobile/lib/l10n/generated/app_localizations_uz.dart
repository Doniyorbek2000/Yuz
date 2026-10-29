// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appTitle => 'Yuz';

  @override
  String get splashTagline => 'Goʻzallik — qurilmangizning oʻzida';

  @override
  String get actionNext => 'Keyingi';

  @override
  String get actionSkip => 'Oʻtkazib yuborish';

  @override
  String get actionGetStarted => 'Boshlash';

  @override
  String get actionContinue => 'Davom etish';

  @override
  String get actionRetry => 'Qayta urinish';

  @override
  String get actionOpenSettings => 'Sozlamalarni ochish';

  @override
  String get actionClose => 'Yopish';

  @override
  String get actionSave => 'Saqlash';

  @override
  String get actionCancel => 'Bekor qilish';

  @override
  String get actionDelete => 'Oʻchirish';

  @override
  String get onboardingTitle1 => 'Real vaqtdagi goʻzallik kamerasi';

  @override
  String get onboardingBody1 => 'Teri teksturasini saqlagan holda tabiiy silliqlash — GPUʼda jonli ishlaydi.';

  @override
  String get onboardingTitle2 => 'Maxfiylik birinchi oʻrinda';

  @override
  String get onboardingBody2 =>
      'Kamera effektlari toʻliq telefoningizda ishlaydi. Lokal funksiyalar uchun hech narsa yuklanmaydi.';

  @override
  String get onboardingTitle3 => 'Sizning uslubingiz, sizning presetlaringiz';

  @override
  String get onboardingBody3 => 'Har bir effektni 0 dan 100 gacha sozlang va sevimli kombinatsiyalarni saqlang.';

  @override
  String get permissionTitle => 'Kameraga ruxsat';

  @override
  String get permissionBody =>
      'Jonli goʻzallik koʻrinishi va suratga olish uchun Yuz kameraga muhtoj. Kadrlar qurilmangizdan chiqmaydi.';

  @override
  String get permissionGrant => 'Kameraga ruxsat berish';

  @override
  String get permissionDenied => 'Kameraga ruxsat berilmadi. Ruxsat bermaguningizcha kamera funksiyalari ishlamaydi.';

  @override
  String get permissionPermanentlyDenied => 'Kameraga ruxsat bloklangan. Tizim sozlamalarida Yuz uchun yoqing.';

  @override
  String get homeGreeting => 'Oʻz uslubingizni yarating';

  @override
  String get homeSectionCamera => 'Kamera';

  @override
  String get homeSectionEditing => 'Tahrirlash';

  @override
  String get homeSectionAi => 'AI studiya';

  @override
  String get homeSectionAccount => 'Hisob';

  @override
  String get featureBeautyCamera => 'Goʻzallik kamerasi';

  @override
  String get featureBeautyCameraSubtitle => 'Jonli teri silliqlash';

  @override
  String get featurePhotoEditor => 'Foto muharriri';

  @override
  String get featureVideoEditor => 'Video muharriri';

  @override
  String get featureAiPhotoshoot => 'AI fotosessiya';

  @override
  String get featureAiHairstyle => 'AI soch turmagi';

  @override
  String get featureAiMakeup => 'AI makiyaj';

  @override
  String get featureAiBackground => 'AI fon';

  @override
  String get featureTemplates => 'Shablonlar';

  @override
  String get featureProjects => 'Loyihalar';

  @override
  String get featurePremium => 'Premium';

  @override
  String get featureCredits => 'Kreditlar';

  @override
  String get featureProfile => 'Profil';

  @override
  String get featureSettings => 'Sozlamalar';

  @override
  String get featureHelp => 'Yordam';

  @override
  String get statusImplemented => 'Tayyor';

  @override
  String get statusPartial => 'Sinov';

  @override
  String get statusNotStarted => 'Rejada';

  @override
  String get featureUnavailableTitle => 'Hozircha mavjud emas';

  @override
  String featureUnavailableBody(String feature, int phase) {
    return '$feature $phase-bosqichda ishlab chiqiladi. Ushbu versiyaga kirmagan.';
  }

  @override
  String get beautyReset => 'Tiklash';

  @override
  String get beautyUndo => 'Bekor qilish';

  @override
  String get beautySavePreset => 'Presetni saqlash';

  @override
  String get beautyPresetNameHint => 'Preset nomi';

  @override
  String get beautyPresets => 'Presetlar';

  @override
  String get beautyPresetNatural => 'Tabiiy';

  @override
  String get beautyPresetSoft => 'Yumshoq';

  @override
  String get beautyPresetGlow => 'Nur';

  @override
  String beautyPresetSaved(String name) {
    return '“$name” preseti saqlandi';
  }

  @override
  String get cameraSwitch => 'Kamerani almashtirish';

  @override
  String get cameraCapture => 'Suratga olish';

  @override
  String get cameraTimer => 'Taymer';

  @override
  String get cameraTimerOff => 'Taymer oʻchiq';

  @override
  String cameraTimerSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get cameraFlash => 'Chiroq';

  @override
  String get cameraFlashOff => 'Chiroq oʻchiq';

  @override
  String get cameraFlashAuto => 'Chiroq avto';

  @override
  String get cameraFlashOn => 'Chiroq yoqiq';

  @override
  String get cameraFlashTorch => 'Fonar';

  @override
  String get cameraZoom => 'Yaqinlashtirish';

  @override
  String get cameraExposure => 'Ekspozitsiya';

  @override
  String get cameraNoFace => 'Yuz aniqlanmadi';

  @override
  String cameraFacesDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count ta yuz', one: '1 ta yuz');
    return '$_temp0';
  }

  @override
  String get cameraTrackingUnavailable => 'Yuz kuzatuvi mavjud emas — faqat teri rangi boʻyicha';

  @override
  String get cameraStarting => 'Kamera ishga tushmoqda…';

  @override
  String cameraMeasuredFps(String fps, String gpu, String detector) {
    return '$fps FPS · GPU $gpu ms · yuz $detector ms';
  }

  @override
  String get cameraPhotoSaved => 'Surat saqlandi';

  @override
  String get errorPermissionDenied => 'Kameraga ruxsat talab qilinadi.';

  @override
  String get errorCameraUnavailable => 'Hozir bu qurilmada kamera mavjud emas.';

  @override
  String get errorCameraInUse => 'Kamerani boshqa ilova ishlatmoqda.';

  @override
  String get errorCameraDisconnected => 'Kamera uzildi.';

  @override
  String get errorGpu => 'Ushbu qurilma GPUʼsi goʻzallik dvigatelini ishga tushira olmadi.';

  @override
  String get errorCaptureFailed => 'Suratni saqlab boʻlmadi.';

  @override
  String get errorThermal => 'Telefon qizib ketdi — yuz kuzatuvi vaqtincha toʻxtatildi.';

  @override
  String get errorUnknown => 'Nimadir notoʻgʻri ketdi.';

  @override
  String get settingsTitle => 'Sozlamalar';

  @override
  String get settingsLanguage => 'Til';

  @override
  String get settingsLanguageSystem => 'Tizim tili';

  @override
  String get settingsPerformanceOverlay => 'Oʻlchangan unumdorlikni koʻrsatish';

  @override
  String get settingsPerformanceOverlaySubtitle => 'Qurilmada oʻlchangan FPS, GPU va yuz kuzatuvi vaqtlari';

  @override
  String get settingsPrivacy => 'Maxfiylik';

  @override
  String get settingsAbout => 'Ilova haqida';

  @override
  String settingsVersion(String version) {
    return 'Versiya $version';
  }

  @override
  String get settingsResetOnboarding => 'Tanishtiruvni qayta koʻrsatish';

  @override
  String get languageUzbek => 'Oʻzbekcha';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get privacyTitle => 'Maxfiylik';

  @override
  String get privacyOnDeviceTitle => 'Qurilmada qayta ishlash';

  @override
  String get privacyOnDeviceBody =>
      'Jonli kamera effektlari, teri silliqlash va yuz kuzatuvi telefoningizda ishlaydi. Bu funksiyalar rasmlarni serverga yubormaydi.';

  @override
  String get privacyStorageTitle => 'Nima saqlanadi';

  @override
  String get privacyStorageBody =>
      'Olingan suratlar ilovaning shaxsiy xotirasida saqlanadi. Sozlamalar va goʻzallik presetlari lokal saqlanadi.';

  @override
  String get privacyCloudTitle => 'Bulutli AI funksiyalar';

  @override
  String get privacyCloudBody =>
      'Bulutli AI funksiyalari biror rasm yuklanishidan oldin aniq roziligingizni soʻraydi. Faqat siz tanlagan rasm shifrlangan aloqa orqali yuboriladi; u ishlovdan soʻng serverdan oʻchiriladi va hech qachon reklama yoki modellarni oʻqitish uchun ishlatilmaydi. Rozilikni Hisob boʻlimida bekor qilishingiz mumkin.';

  @override
  String get privacyDeletionTitle => 'Maʼlumotlarni oʻchirish';

  @override
  String get privacyDeletionBody =>
      'Ilovani oʻchirish qurilmada saqlangan barcha rasmlar, presetlar va sozlamalarni oʻchiradi. Hisobingiz va serverda saqlangan barcha narsalarni Hisob boʻlimida oʻchirish mumkin.';

  @override
  String get tabLooks => 'Obrazlar';

  @override
  String get tabFilters => 'Filtrlar';

  @override
  String get tabSkin => 'Teri';

  @override
  String get tabFace => 'Yuz';

  @override
  String get tabReshape => 'Shakl';

  @override
  String get tabMakeup => 'Makiyaj';

  @override
  String get tabCamera => 'Kamera';

  @override
  String get effectSkinSmoothing => 'Silliqlash';

  @override
  String get effectTexturePreservation => 'Tekstura';

  @override
  String get effectSkinBrightening => 'Yorqinlik';

  @override
  String get effectSkinTone => 'Tekis rang';

  @override
  String get effectBlemishReduction => 'Dogʼlar';

  @override
  String get effectShineReduction => 'Matlik';

  @override
  String get effectGlow => 'Nur';

  @override
  String get effectEyeBrightening => 'Koʼz yorqinligi';

  @override
  String get effectTeethWhitening => 'Tishlar';

  @override
  String get effectDarkCircles => 'Koʼz osti';

  @override
  String get effectFaceSlim => 'Ingichka yuz';

  @override
  String get effectJawline => 'Jagʼ chizigʼi';

  @override
  String get effectChin => 'Iyak';

  @override
  String get effectEyeEnlarge => 'Katta koʼzlar';

  @override
  String get effectNoseSlim => 'Burun';

  @override
  String get effectLips => 'Toʼliq lablar';

  @override
  String get effectForehead => 'Peshona';

  @override
  String get effectLipstick => 'Lab boʼyogʼi';

  @override
  String get effectBlush => 'Qizillik';

  @override
  String get effectEyebrows => 'Qoshlar';

  @override
  String get effectEyeshadow => 'Koʼz soyasi';

  @override
  String get effectEyeliner => 'Koʼz chizigʼi';

  @override
  String get effectMakeupIntensity => 'Makiyaj kuchi';

  @override
  String get effectFilterIntensity => 'Kuch';

  @override
  String get filterNone => 'Asl';

  @override
  String get filterNatural => 'Tabiiy';

  @override
  String get filterSoft => 'Yumshoq';

  @override
  String get filterGlow => 'Nur';

  @override
  String get filterPortrait => 'Portret';

  @override
  String get filterCinematic => 'Kino';

  @override
  String get filterWarm => 'Iliq';

  @override
  String get filterCool => 'Salqin';

  @override
  String get filterVintage => 'Vintaj';

  @override
  String get filterBlackWhite => 'Oq-qora';

  @override
  String get filterCustom => 'Mening LUT';

  @override
  String get filterImport => 'LUT yuklash';

  @override
  String get lutImported => 'LUT yuklandi';

  @override
  String get lutImportWrongSize => 'LUT rasmi 512×512 piksel boʼlishi kerak.';

  @override
  String get lutImportUnreadable => 'Bu rasmni oʼqib boʼlmadi.';

  @override
  String get beautyPresetEverydayMakeup => 'Kundalik';

  @override
  String get beautyPresetEveningMakeup => 'Kechki';

  @override
  String get requiresFaceTracking => 'Yuz kuzatuvi kerak — kameraga qarang';

  @override
  String get makeupShade => 'Rang';

  @override
  String get effectSharpen => 'Aniqlik';

  @override
  String get projectsTitle => 'Loyihalar';

  @override
  String get projectsNew => 'Yangi surat';

  @override
  String get projectsEmptyTitle => 'Hali loyihalar yoʼq';

  @override
  String get projectsEmptyBody => 'Retush qilish uchun surat tanlang. Asl surat hech qachon oʼzgarmaydi.';

  @override
  String get projectsDeleteTitle => 'Loyihani oʼchirasizmi?';

  @override
  String get projectsDeleteBody =>
      'Ilovadagi nusxa, tahrirlar va eksportlar oʼchiriladi. Galereyaga saqlangan suratlar qoladi.';

  @override
  String get projectsImportFailed => 'Bu faylni import qilib boʼlmadi.';

  @override
  String get photoRetouchTitle => 'Retush';

  @override
  String get photoNext => 'Tahrirlash';

  @override
  String get photoCompare => 'Solishtirish uchun bosib turing';

  @override
  String get photoPreparing => 'Toʼliq oʼlchamdagi rasm tayyorlanmoqda…';

  @override
  String get photoNotFound => 'Bu loyiha endi mavjud emas.';

  @override
  String get photoRenderFailed => 'Suratni qayta ishlab boʼlmadi.';

  @override
  String get photoSavedToGallery => 'Galereyaga saqlandi';

  @override
  String get photoSavedInApp => 'Yuz ichida saqlandi (galereyaga ruxsat yoʼq)';

  @override
  String get photoSaveFailed => 'Tahrirni saqlab boʼlmadi.';

  @override
  String get editorPaint => 'Chizish';

  @override
  String get editorText => 'Matn';

  @override
  String get editorCrop => 'Kesish';

  @override
  String get editorTune => 'Sozlash';

  @override
  String get editorBlur => 'Xiralash';

  @override
  String get editorEmoji => 'Emoji';

  @override
  String get editorStickers => 'Stikerlar';

  @override
  String get editorBrightness => 'Yorqinlik';

  @override
  String get editorContrast => 'Kontrast';

  @override
  String get editorSaturation => 'Toʼyinganlik';

  @override
  String get editorExposure => 'Ekspozitsiya';

  @override
  String get editorHue => 'Tus';

  @override
  String get editorTemperature => 'Harorat';

  @override
  String get editorFade => 'Soʼndirish';

  @override
  String get editorTint => 'Tonlash';

  @override
  String get editorRotate => 'Burish';

  @override
  String get editorFlip => 'Aylantirish';

  @override
  String get editorRatio => 'Nisbat';

  @override
  String get editorReset => 'Tiklash';

  @override
  String get editorTextHint => 'Matn kiriting';

  @override
  String get editorDone => 'Tayyor';

  @override
  String get editorBack => 'Orqaga';

  @override
  String get editorUndo => 'Bekor qilish';

  @override
  String get editorRedo => 'Qaytarish';

  @override
  String get editorRemove => 'Oʼchirish';

  @override
  String get editorEdit => 'Tahrirlash';

  @override
  String get editorApplying => 'Oʼzgarishlar qoʼllanmoqda…';

  @override
  String get editorLoading => 'Kuting…';

  @override
  String get editorCloseTitle => 'Muharrirni yopasizmi?';

  @override
  String get editorCloseBody => 'Tahrirlaringiz loyihada saqlanadi.';

  @override
  String get editorEraser => 'Oʼchirgʼich';

  @override
  String get editorLineWidth => 'Chiziq qalinligi';

  @override
  String get editorOpacity => 'Shaffoflik';

  @override
  String get editorColor => 'Rang';

  @override
  String get editorSearch => 'Qidirish';

  @override
  String get editorAlign => 'Matnni tekislash';

  @override
  String get editorRotateScale => 'Burish va oʼlcham';

  @override
  String get cameraModePhoto => 'Foto';

  @override
  String get cameraModeVideo => 'Video';

  @override
  String get cameraRecordStart => 'Yozishni boshlash';

  @override
  String get cameraRecordStop => 'Yozishni toʻxtatish';

  @override
  String get cameraRecording => 'Yozilmoqda';

  @override
  String get cameraRecordingNoSound => 'Ovozsiz: mikrofonga ruxsat berilmagan';

  @override
  String get errorRecordingFailed => 'Videoni yozib boʻlmadi.';

  @override
  String get videoResultTitle => 'Video';

  @override
  String get videoSaveToGallery => 'Galereyaga saqlash';

  @override
  String get videoSavedToGallery => 'Galereyaga saqlandi';

  @override
  String get videoSaveFailed => 'Galereyaga saqlab boʻlmadi. Sozlamalarda rasmlarga ruxsatni tekshiring.';

  @override
  String get videoNotFound => 'Bu video endi mavjud emas.';

  @override
  String get videoPlay => 'Ijro etish';

  @override
  String get videoPause => 'Pauza';

  @override
  String get videoEdit => 'Videoni tahrirlash';

  @override
  String get videoSilent => 'Ovozsiz yozilgan';

  @override
  String get errorExportCancelled => 'Eksport bekor qilindi.';

  @override
  String get videoEditorTitle => 'Videoni tahrirlash';

  @override
  String get videoExport => 'Eksport';

  @override
  String videoExporting(int percent) {
    return 'Eksport qilinmoqda… $percent%';
  }

  @override
  String get videoExportFailed => 'Videoni eksport qilib boʻlmadi.';

  @override
  String get videoToolTrim => 'Kesish';

  @override
  String get videoToolSpeed => 'Tezlik';

  @override
  String get videoToolLook => 'Koʻrinish';

  @override
  String get videoToolText => 'Matn';

  @override
  String get videoToolStickers => 'Stikerlar';

  @override
  String get videoToolMusic => 'Musiqa';

  @override
  String get videoAddClip => 'Klip qoʻshish';

  @override
  String get videoRemoveClip => 'Klipni oʻchirish';

  @override
  String get videoSpeedMutes => 'Tezligi oʻzgargan klip oʻz ovozisiz ijro etiladi; musiqa eshitiladi.';

  @override
  String get videoApplyBeauty => 'Yuzlarga beauty';

  @override
  String get videoApplyBeautyHint => 'Oʻchirilsa, faqat filtr va aniqlik qoladi.';

  @override
  String get videoLookPreview => 'Koʻrinish namunasi (bitta kadr)';

  @override
  String get videoAddText => 'Matn qoʻshish';

  @override
  String get videoTextDialogTitle => 'Matn';

  @override
  String get videoTextHint => 'Matningiz';

  @override
  String get videoOverlayTime => 'Koʻrinadi';

  @override
  String get videoOverlayDelete => 'Oʻchirish';

  @override
  String get videoOverlayHint =>
      'Tanlash uchun bosing, surish uchun torting, oʻlcham va burish uchun ikki barmoq bilan ishlating.';

  @override
  String get videoMusicPick => 'Tanlash';

  @override
  String get videoMusicNone => 'Musiqa yoʻq';

  @override
  String get videoMusicSelected => 'Musiqa qoʻshildi (takrorlanadi, oxirida pasayadi)';

  @override
  String get videoMusicRemove => 'Musiqani olib tashlash';

  @override
  String get videoMusicVolume => 'Musiqa';

  @override
  String get videoOriginalVolume => 'Klip ovozi';

  @override
  String get videoImportFailed => 'Bu videoni import qilib boʻlmadi.';

  @override
  String get projectsPhotosTab => 'Fotolar';

  @override
  String get projectsVideosTab => 'Videolar';

  @override
  String get projectsNewVideo => 'Yangi video';

  @override
  String get projectsVideoEmptyBody => 'Video import qiling yoki kamerada yozing. Asl fayl hech qachon oʻzgarmaydi.';

  @override
  String get templatesTitle => 'Shablonlar';

  @override
  String get templatesSave => 'Saqlash';

  @override
  String get templatesSlotHint => 'Rasmni surish uchun torting, kattalashtirish uchun ikki barmoq bilan ishlating.';

  @override
  String get templatesReplace => 'Almashtirish';

  @override
  String get templatesBackground => 'Fon';

  @override
  String get templatesSpacing => 'Oraliq';

  @override
  String get templatesCorners => 'Burchaklar';

  @override
  String get templatesCaptionHint => 'Izoh (ixtiyoriy)';

  @override
  String get statusBlocked => 'Bloklangan';

  @override
  String featureBlockedBody(String feature) {
    return '$feature uchun generativ AI model xizmati (pullik API yoki GPU serverlar) kerak. Bu xizmat tasdiqlangach yoqiladi. Ungacha hech narsa hisobdan yechilmaydi.';
  }

  @override
  String get errorNetwork => 'Server bilan aloqa yoʻq. Internetni tekshirib, qayta urinib koʻring.';

  @override
  String get errorTimeout => 'Server juda uzoq javob bermadi. Qayta urinib koʻring.';

  @override
  String get errorSessionExpired => 'Seans tugadi. Qaytadan kiring.';

  @override
  String get errorInvalidCredentials => 'Email yoki parol notoʻgʻri.';

  @override
  String get errorEmailTaken => 'Bu email bilan hisob allaqachon mavjud.';

  @override
  String get errorRateLimited => 'Urinishlar juda koʻp. Bir daqiqa kutib, qayta urinib koʻring.';

  @override
  String get errorInvalidPassword => 'Parol notoʻgʻri.';

  @override
  String get errorInsufficientCredits => 'Buning uchun kreditlar yetarli emas.';

  @override
  String get errorConsentRequired => 'Avval bulutli AI ishloviga ruxsat bering.';

  @override
  String get errorAiUnavailable => 'Bu AI funksiyasi hozir serverda mavjud emas. Kredit yechilmadi.';

  @override
  String get errorUnsupportedImage => 'Bu rasm formati qoʻllab-quvvatlanmaydi. JPEG yoki PNG ishlating.';

  @override
  String get errorImageTooLarge => 'Rasm juda katta.';

  @override
  String get errorNoPerson =>
      'Rasmda odam topilmadi. Odam aniq koʻrinadigan rasmni tanlang. Kreditlaringiz qaytarildi.';

  @override
  String get errorProcessingTimeout => 'Ishlov odatdagidan uzoq davom etmoqda. Keyinroq qayta urinib koʻring.';

  @override
  String get errorJobCancelled => 'Vazifa bekor qilindi. Kreditlaringiz qaytarildi.';

  @override
  String get errorProcessingFailed => 'Ishlov muvaffaqiyatsiz tugadi. Kreditlaringiz qaytarildi.';

  @override
  String get errorFile => 'Rasmni bu qurilmada oʻqib yoki saqlab boʻlmadi.';

  @override
  String get errorServer => 'Serverda muammo yuz berdi. Keyinroq qayta urinib koʻring.';

  @override
  String get accountTitle => 'Hisob';

  @override
  String get accountUnconfiguredTitle => 'Bu versiyada hisoblar mavjud emas';

  @override
  String get accountUnconfiguredBody =>
      'Bu versiya Yuz serveriga ulanmagan. Kamera, tahrirlash va qurilmadagi barcha effektlar hisobsiz ishlaydi.';

  @override
  String get accountSignedOutBody => 'Bulutli AI funksiyalaridan foydalanish va kreditlaringizni saqlash uchun kiring.';

  @override
  String get accountSignIn => 'Kirish';

  @override
  String get accountCreate => 'Hisob yaratish';

  @override
  String get accountLoadFailed => 'Hisobni yuklab boʻlmadi.';

  @override
  String accountCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count kredit');
    return '$_temp0';
  }

  @override
  String accountPremiumActive(String date) {
    return 'Premium $date gacha';
  }

  @override
  String get accountPremiumInactive => 'Premium faol emas';

  @override
  String get accountStore => 'Kreditlar va Premium';

  @override
  String get accountCloudAi => 'Bulutli AI ishlovi';

  @override
  String get accountCloudAiOn =>
      'Ruxsat berilgan. AI funksiyalariga yuborgan rasmlaringiz Yuz serverlarida qayta ishlanadi.';

  @override
  String get accountCloudAiOff => 'Ruxsat berilmagan. Hech narsa yuklanmaydi.';

  @override
  String get accountRevokeTitle => 'Bulutli AI ishlovini toʻxtatasizmi?';

  @override
  String get accountRevokeBody =>
      'Navbatdagi vazifalar bekor qilinadi, kreditlar qaytariladi va yuklangan rasmlar oʻchiriladi.';

  @override
  String get accountRevokeConfirm => 'Toʻxtatish';

  @override
  String get accountDisplayName => 'Koʻrinadigan ism';

  @override
  String get accountExport => 'Maʼlumotlarimni yuklab olish';

  @override
  String get accountExportDone => 'Maʼlumotlaringiz saqlandi.';

  @override
  String get accountSignOut => 'Chiqish';

  @override
  String get accountDelete => 'Hisobni oʻchirish';

  @override
  String get accountDeleteBody =>
      'Bu hisobingiz, kreditlaringiz, AI vazifalari va yuklangan rasmlarni butunlay oʻchiradi. Telefondagi loyihalar qoladi. Tasdiqlash uchun parolingizni kiriting.';

  @override
  String get accountDeleteConfirm => 'Butunlay oʻchirish';

  @override
  String get accountDeleted => 'Hisobingiz oʻchirildi.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Parol';

  @override
  String get authPasswordHint => 'Kamida 10 ta belgi';

  @override
  String get authName => 'Ism (ixtiyoriy)';

  @override
  String get authEmailInvalid => 'Toʻgʻri email kiriting';

  @override
  String get authPasswordShort => 'Kamida 10 ta belgi kiriting';

  @override
  String get authPasswordRequired => 'Parolingizni kiriting';

  @override
  String get authShowPassword => 'Parolni koʻrsatish';

  @override
  String get authHidePassword => 'Parolni yashirish';

  @override
  String get authSwitchToRegister => 'Hisobingiz yoʻqmi? Yarating';

  @override
  String get authSwitchToSignIn => 'Hisobingiz bormi? Kiring';

  @override
  String get authSecurityNote =>
      'Parolingiz faqat shifrlangan aloqa orqali yuboriladi va matn sifatida emas, tuzlangan xesh koʻrinishida saqlanadi.';

  @override
  String get consentIntro =>
      'Fonni almashtirish kabi AI funksiyalari Yuz serverlarida ishlaydi. Biror narsa yuklanishidan oldin aynan nima boʻlishini bilib oling:';

  @override
  String get consentPointUpload => 'Faqat AI funksiyasi uchun tanlagan rasmingiz shifrlangan aloqa orqali yuklanadi.';

  @override
  String get consentPointDelete =>
      'Yuklangan rasm ishlov tugashi bilan serverdan oʻchiriladi. Natija telefoningizga yetib kelgach oʻchiriladi; qolgan narsalar avtomatik tozalanadi.';

  @override
  String get consentPointUse =>
      'Rasmlar faqat natijangizni tayyorlash uchun ishlatiladi — hech qachon reklama yoki modellarni oʻqitish uchun emas.';

  @override
  String get consentPointPeople => 'Faqat oʻzingizning yoki rozi boʻlgan odamlarning rasmlarini yuklang.';

  @override
  String get consentPointLocal =>
      'Goʻzallik kamerasi, retush va filtrlar bu ruxsatsiz ham telefoningizda toʻliq ishlayveradi.';

  @override
  String get consentPointRevoke => 'Bu ruxsatni istalgan vaqtda Hisob boʻlimida bekor qilishingiz mumkin.';

  @override
  String get consentAccept => 'Bulutli AI ga ruxsat berish';

  @override
  String get consentDecline => 'Hozir emas';

  @override
  String consentVersion(String version) {
    return 'Rozilik versiyasi $version';
  }

  @override
  String get storeBalance => 'Balans';

  @override
  String get storeBlockedTitle => 'Xaridlar hali yoqilmagan';

  @override
  String get storeBlockedBody =>
      'Kredit va Premium sotib olish uchun App Store va Google Play mahsulotlari hamda ularni serverda tekshirish sozlanishi kerak. Ungacha hech qanday toʻlov olinmaydi.';

  @override
  String storePremium(int days) {
    return 'Premium · $days kun';
  }

  @override
  String get storeUnavailable => 'Mavjud emas';

  @override
  String get storePrices => 'AI narxlari';

  @override
  String get storeHistory => 'Tarix';

  @override
  String get storeHistoryEmpty => 'Hali kredit harakatlari yoʻq.';

  @override
  String get creditKindWelcome => 'Xush kelibsiz bonusi';

  @override
  String get creditKindPurchase => 'Xarid';

  @override
  String get creditKindSpend => 'AI ishlovi';

  @override
  String get creditKindRefund => 'Qaytarish';

  @override
  String get creditKindAdjustment => 'Tuzatish';

  @override
  String get aiBgIntro =>
      'Odamlar ortidagi fonni xiralashtiring, rangini almashtiring yoki olib tashlang. Yuz serverlarida qayta ishlanadi.';

  @override
  String get aiPickGallery => 'Rasm tanlash';

  @override
  String get aiPickCamera => 'Rasmga olish';

  @override
  String get aiPickHint => 'Odam bor rasmni tanlang';

  @override
  String get aiModeBlur => 'Xiralashtirish';

  @override
  String get aiModeColor => 'Rang';

  @override
  String get aiModeRemove => 'Olib tashlash';

  @override
  String aiStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Ishlov berish · $count kredit');
    return '$_temp0';
  }

  @override
  String aiBalance(int count) {
    return 'Balans: $count';
  }

  @override
  String get aiStageUploading => 'Yuklanmoqda…';

  @override
  String get aiStageQueued => 'Navbatda kutmoqda…';

  @override
  String get aiStageRunning => 'Qayta ishlanmoqda…';

  @override
  String get aiStageDownloading => 'Natija yuklab olinmoqda…';

  @override
  String get aiViewOriginal => 'Asl';

  @override
  String get aiViewResult => 'Natija';

  @override
  String get aiOpenEditor => 'Yuzda tahrirlash';

  @override
  String get aiSignInRequired => 'AI fondan foydalanish uchun hisobingizga kiring.';

  @override
  String get aiConsentRequired => 'Davom etish uchun bulutli AI ishloviga ruxsat bering.';

  @override
  String get aiReviewConsent => 'Koʻrib chiqish va ruxsat berish';

  @override
  String get aiPrivacyNote => 'Faqat shu rasm yuklanadi. Ishlovdan soʻng serverdan oʻchiriladi.';

  @override
  String get helpIntro => 'Koʻp beriladigan savollarga javoblar.';

  @override
  String get helpUploadQ => 'Rasmlarim yuklanadimi?';

  @override
  String get helpUploadA =>
      'Yoʻq. Goʻzallik kamerasi, retush, filtrlar, stikerlar, shablonlar va video muharriri toʻliq telefoningizda ishlaydi. Rasm telefondan faqat bulutli AI funksiyasidan foydalanganingizda va bunga ruxsat berganingizdan keyin chiqadi.';

  @override
  String get helpCreditsQ => 'Kreditlar nima?';

  @override
  String get helpCreditsA =>
      'Bulutli AI funksiyalari server hisoblash vaqtidan foydalanadi va kredit talab qiladi. Yangi hisoblarga bepul xush kelibsiz kreditlari beriladi. Ishlov muvaffaqiyatsiz boʻlsa, kreditlar avtomatik qaytariladi.';

  @override
  String get helpBlockedQ => 'Nega baʼzi AI funksiyalari mavjud emas?';

  @override
  String get helpBlockedA =>
      'AI fotosessiya, soch turmagi va makiyaj uchun hali yoqilmagan generativ model xizmati kerak. Ular bloklangan deb belgilangan va hech qachon kredit yechmaydi.';

  @override
  String get helpDeleteQ => 'Maʼlumotlarimni qanday oʻchiraman?';

  @override
  String get helpDeleteA =>
      'Loyihalar telefoningizda saqlanadi; ularni Loyihalar boʻlimida oʻchiring. Hisobingiz va serverdagi barcha narsalarni Hisob → Hisobni oʻchirish orqali oʻchirish mumkin. Avval “Maʼlumotlarimni yuklab olish” orqali nusxa oling.';

  @override
  String get helpCameraQ => 'Kamera qora ekran koʻrsatmoqda';

  @override
  String get helpCameraA =>
      'Tizim sozlamalarida kameraga ruxsat berilganini tekshiring va kameradan foydalanayotgan boshqa ilovalarni yoping.';

  @override
  String get helpSavedQ => 'Saqlangan rasm va videolarim qayerda?';

  @override
  String get helpSavedA =>
      'Telefoningiz galereyasidagi “Yuz” albomida. Eksport qilinmagan loyihalar ilova ichida qoladi.';
}
