// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Yuz';

  @override
  String get splashTagline => 'Красота, обработанная на вашем устройстве';

  @override
  String get actionNext => 'Далее';

  @override
  String get actionSkip => 'Пропустить';

  @override
  String get actionGetStarted => 'Начать';

  @override
  String get actionContinue => 'Продолжить';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get actionOpenSettings => 'Открыть настройки';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get actionSave => 'Сохранить';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionDelete => 'Удалить';

  @override
  String get onboardingTitle1 => 'Бьюти-камера в реальном времени';

  @override
  String get onboardingBody1 => 'Естественное сглаживание кожи с сохранением текстуры — прямо на GPU.';

  @override
  String get onboardingTitle2 => 'Приватность по умолчанию';

  @override
  String get onboardingBody2 =>
      'Эффекты камеры работают полностью на телефоне. Для локальных функций ничего не загружается.';

  @override
  String get onboardingTitle3 => 'Ваш образ, ваши пресеты';

  @override
  String get onboardingBody3 => 'Настраивайте каждый эффект от 0 до 100 и сохраняйте любимые комбинации.';

  @override
  String get permissionTitle => 'Доступ к камере';

  @override
  String get permissionBody => 'Yuz нужна камера для живого бьюти-превью и съёмки. Кадры не покидают устройство.';

  @override
  String get permissionGrant => 'Разрешить камеру';

  @override
  String get permissionDenied => 'Доступ к камере отклонён. Функции камеры недоступны, пока вы его не разрешите.';

  @override
  String get permissionPermanentlyDenied => 'Доступ к камере заблокирован. Включите его для Yuz в настройках системы.';

  @override
  String get homeGreeting => 'Создайте свой образ';

  @override
  String get homeSectionCamera => 'Камера';

  @override
  String get homeSectionEditing => 'Редактирование';

  @override
  String get homeSectionAi => 'AI-студия';

  @override
  String get homeSectionAccount => 'Аккаунт';

  @override
  String get featureBeautyCamera => 'Бьюти-камера';

  @override
  String get featureBeautyCameraSubtitle => 'Живое сглаживание кожи';

  @override
  String get featurePhotoEditor => 'Фоторедактор';

  @override
  String get featureVideoEditor => 'Видеоредактор';

  @override
  String get featureAiPhotoshoot => 'AI-фотосессия';

  @override
  String get featureAiHairstyle => 'AI-причёска';

  @override
  String get featureAiMakeup => 'AI-макияж';

  @override
  String get featureAiBackground => 'AI-фон';

  @override
  String get featureTemplates => 'Шаблоны';

  @override
  String get featureProjects => 'Проекты';

  @override
  String get featurePremium => 'Premium';

  @override
  String get featureCredits => 'Кредиты';

  @override
  String get featureProfile => 'Профиль';

  @override
  String get featureSettings => 'Настройки';

  @override
  String get featureHelp => 'Помощь';

  @override
  String get statusImplemented => 'Готово';

  @override
  String get statusPartial => 'Превью';

  @override
  String get statusNotStarted => 'В планах';

  @override
  String get featureUnavailableTitle => 'Пока недоступно';

  @override
  String featureUnavailableBody(String feature, int phase) {
    return '«$feature» запланировано на этап разработки $phase. В эту сборку не входит.';
  }

  @override
  String get beautyReset => 'Сброс';

  @override
  String get beautyUndo => 'Отменить';

  @override
  String get beautySavePreset => 'Сохранить пресет';

  @override
  String get beautyPresetNameHint => 'Название пресета';

  @override
  String get beautyPresets => 'Пресеты';

  @override
  String get beautyPresetNatural => 'Натуральный';

  @override
  String get beautyPresetSoft => 'Мягкий';

  @override
  String get beautyPresetGlow => 'Сияние';

  @override
  String beautyPresetSaved(String name) {
    return 'Пресет «$name» сохранён';
  }

  @override
  String get cameraSwitch => 'Сменить камеру';

  @override
  String get cameraCapture => 'Сделать фото';

  @override
  String get cameraTimer => 'Таймер';

  @override
  String get cameraTimerOff => 'Таймер выкл.';

  @override
  String cameraTimerSeconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get cameraFlash => 'Вспышка';

  @override
  String get cameraFlashOff => 'Вспышка выкл.';

  @override
  String get cameraFlashAuto => 'Вспышка авто';

  @override
  String get cameraFlashOn => 'Вспышка вкл.';

  @override
  String get cameraFlashTorch => 'Фонарик';

  @override
  String get cameraZoom => 'Зум';

  @override
  String get cameraExposure => 'Экспозиция';

  @override
  String get cameraNoFace => 'Лицо не найдено';

  @override
  String cameraFacesDetected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count лица',
      many: '$count лиц',
      few: '$count лица',
      one: '1 лицо',
    );
    return '$_temp0';
  }

  @override
  String get cameraTrackingUnavailable => 'Трекинг лица недоступен — только по тону кожи';

  @override
  String get cameraStarting => 'Запуск камеры…';

  @override
  String cameraMeasuredFps(String fps, String gpu, String detector) {
    return '$fps FPS · GPU $gpu мс · лицо $detector мс';
  }

  @override
  String get cameraPhotoSaved => 'Фото сохранено';

  @override
  String get errorPermissionDenied => 'Требуется разрешение на камеру.';

  @override
  String get errorCameraUnavailable => 'Камера сейчас недоступна на этом устройстве.';

  @override
  String get errorCameraInUse => 'Камера занята другим приложением.';

  @override
  String get errorCameraDisconnected => 'Камера отключилась.';

  @override
  String get errorGpu => 'GPU этого устройства не смог запустить бьюти-движок.';

  @override
  String get errorCaptureFailed => 'Не удалось сохранить фото.';

  @override
  String get errorThermal => 'Телефон перегрелся — трекинг лица приостановлен.';

  @override
  String get errorUnknown => 'Что-то пошло не так.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get settingsLanguageSystem => 'Как в системе';

  @override
  String get settingsPerformanceOverlay => 'Показывать измеренную производительность';

  @override
  String get settingsPerformanceOverlaySubtitle => 'FPS, время GPU и трекинга лица, измеренные на устройстве';

  @override
  String get settingsPrivacy => 'Конфиденциальность';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String settingsVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get settingsResetOnboarding => 'Показать знакомство снова';

  @override
  String get languageUzbek => 'Oʻzbekcha';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get privacyTitle => 'Конфиденциальность';

  @override
  String get privacyOnDeviceTitle => 'Обработка на устройстве';

  @override
  String get privacyOnDeviceBody =>
      'Живые эффекты камеры, сглаживание кожи и трекинг лица работают на телефоне. Эти функции никогда не отправляют изображения на сервер.';

  @override
  String get privacyStorageTitle => 'Что хранится';

  @override
  String get privacyStorageBody =>
      'Снятые фото сохраняются в приватном хранилище приложения. Настройки и бьюти-пресеты хранятся локально.';

  @override
  String get privacyCloudTitle => 'Облачные AI-функции';

  @override
  String get privacyCloudBody =>
      'Будущие облачные AI-функции запросят явное согласие перед загрузкой любого фото — и только для ваших фото или людей, давших согласие.';

  @override
  String get privacyDeletionTitle => 'Удаление данных';

  @override
  String get privacyDeletionBody => 'Удаление приложения стирает все локальные фото, пресеты и настройки.';

  @override
  String get tabLooks => 'Образы';

  @override
  String get tabFilters => 'Фильтры';

  @override
  String get tabSkin => 'Кожа';

  @override
  String get tabFace => 'Лицо';

  @override
  String get tabReshape => 'Форма';

  @override
  String get tabMakeup => 'Макияж';

  @override
  String get tabCamera => 'Камера';

  @override
  String get effectSkinSmoothing => 'Сглаживание';

  @override
  String get effectTexturePreservation => 'Текстура';

  @override
  String get effectSkinBrightening => 'Сияние';

  @override
  String get effectSkinTone => 'Ровный тон';

  @override
  String get effectBlemishReduction => 'Несовершенства';

  @override
  String get effectShineReduction => 'Матовость';

  @override
  String get effectGlow => 'Свечение';

  @override
  String get effectEyeBrightening => 'Яркие глаза';

  @override
  String get effectTeethWhitening => 'Зубы';

  @override
  String get effectDarkCircles => 'Круги под глазами';

  @override
  String get effectFaceSlim => 'Тонкое лицо';

  @override
  String get effectJawline => 'Линия челюсти';

  @override
  String get effectChin => 'Подбородок';

  @override
  String get effectEyeEnlarge => 'Большие глаза';

  @override
  String get effectNoseSlim => 'Нос';

  @override
  String get effectLips => 'Пухлые губы';

  @override
  String get effectForehead => 'Лоб';

  @override
  String get effectLipstick => 'Помада';

  @override
  String get effectBlush => 'Румяна';

  @override
  String get effectEyebrows => 'Брови';

  @override
  String get effectEyeshadow => 'Тени';

  @override
  String get effectEyeliner => 'Подводка';

  @override
  String get effectMakeupIntensity => 'Сила макияжа';

  @override
  String get effectFilterIntensity => 'Интенсивность';

  @override
  String get filterNone => 'Оригинал';

  @override
  String get filterNatural => 'Натуральный';

  @override
  String get filterSoft => 'Мягкий';

  @override
  String get filterGlow => 'Сияние';

  @override
  String get filterPortrait => 'Портрет';

  @override
  String get filterCinematic => 'Кино';

  @override
  String get filterWarm => 'Тёплый';

  @override
  String get filterCool => 'Холодный';

  @override
  String get filterVintage => 'Винтаж';

  @override
  String get filterBlackWhite => 'Ч/Б';

  @override
  String get filterCustom => 'Мой LUT';

  @override
  String get filterImport => 'Загрузить LUT';

  @override
  String get lutImported => 'LUT загружен';

  @override
  String get lutImportWrongSize => 'Изображение LUT должно быть 512×512 пикселей.';

  @override
  String get lutImportUnreadable => 'Не удалось прочитать изображение.';

  @override
  String get beautyPresetEverydayMakeup => 'На каждый день';

  @override
  String get beautyPresetEveningMakeup => 'Вечерний';

  @override
  String get requiresFaceTracking => 'Нужен трекинг лица — смотрите в камеру';

  @override
  String get makeupShade => 'Оттенок';

  @override
  String get effectSharpen => 'Резкость';

  @override
  String get projectsTitle => 'Проекты';

  @override
  String get projectsNew => 'Новое фото';

  @override
  String get projectsEmptyTitle => 'Пока нет проектов';

  @override
  String get projectsEmptyBody => 'Выберите фото для ретуши. Оригинал никогда не изменяется.';

  @override
  String get projectsDeleteTitle => 'Удалить проект?';

  @override
  String get projectsDeleteBody => 'Копия, правки и экспорты в приложении будут удалены. Фото в галерее останутся.';

  @override
  String get projectsImportFailed => 'Не удалось импортировать файл.';

  @override
  String get photoRetouchTitle => 'Ретушь';

  @override
  String get photoNext => 'Редактировать';

  @override
  String get photoCompare => 'Удерживайте для сравнения';

  @override
  String get photoPreparing => 'Подготовка изображения в полном размере…';

  @override
  String get photoNotFound => 'Этот проект больше не существует.';

  @override
  String get photoRenderFailed => 'Не удалось обработать фото.';

  @override
  String get photoSavedToGallery => 'Сохранено в галерею';

  @override
  String get photoSavedInApp => 'Сохранено в Yuz (нет доступа к галерее)';

  @override
  String get photoSaveFailed => 'Не удалось сохранить правку.';

  @override
  String get editorPaint => 'Рисование';

  @override
  String get editorText => 'Текст';

  @override
  String get editorCrop => 'Обрезка';

  @override
  String get editorTune => 'Настройка';

  @override
  String get editorBlur => 'Размытие';

  @override
  String get editorEmoji => 'Эмодзи';

  @override
  String get editorStickers => 'Стикеры';

  @override
  String get editorBrightness => 'Яркость';

  @override
  String get editorContrast => 'Контраст';

  @override
  String get editorSaturation => 'Насыщенность';

  @override
  String get editorExposure => 'Экспозиция';

  @override
  String get editorHue => 'Оттенок';

  @override
  String get editorTemperature => 'Температура';

  @override
  String get editorFade => 'Выцветание';

  @override
  String get editorTint => 'Тонирование';

  @override
  String get editorRotate => 'Повернуть';

  @override
  String get editorFlip => 'Отразить';

  @override
  String get editorRatio => 'Пропорции';

  @override
  String get editorReset => 'Сброс';

  @override
  String get editorTextHint => 'Введите текст';

  @override
  String get editorDone => 'Готово';

  @override
  String get editorBack => 'Назад';

  @override
  String get editorUndo => 'Отменить';

  @override
  String get editorRedo => 'Повторить';

  @override
  String get editorRemove => 'Удалить';

  @override
  String get editorEdit => 'Изменить';

  @override
  String get editorApplying => 'Применение изменений…';

  @override
  String get editorLoading => 'Подождите…';

  @override
  String get editorCloseTitle => 'Закрыть редактор?';

  @override
  String get editorCloseBody => 'Правки сохранятся в проекте.';

  @override
  String get editorEraser => 'Ластик';

  @override
  String get editorLineWidth => 'Толщина линии';

  @override
  String get editorOpacity => 'Непрозрачность';

  @override
  String get editorColor => 'Цвет';

  @override
  String get editorSearch => 'Поиск';

  @override
  String get editorAlign => 'Выравнивание';

  @override
  String get editorRotateScale => 'Поворот и масштаб';
}
