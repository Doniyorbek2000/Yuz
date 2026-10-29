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
      'Облачные AI-функции запрашивают явное согласие перед загрузкой любого фото. Отправляется только выбранное фото по зашифрованному соединению; после обработки оно удаляется с сервера и никогда не используется для рекламы или обучения моделей. Согласие можно отозвать в разделе «Аккаунт».';

  @override
  String get privacyDeletionTitle => 'Удаление данных';

  @override
  String get privacyDeletionBody =>
      'Удаление приложения стирает все локальные фото, пресеты и настройки. Аккаунт и всё, что хранится на сервере, можно удалить в разделе «Аккаунт».';

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

  @override
  String get cameraModePhoto => 'Фото';

  @override
  String get cameraModeVideo => 'Видео';

  @override
  String get cameraRecordStart => 'Начать запись';

  @override
  String get cameraRecordStop => 'Остановить запись';

  @override
  String get cameraRecording => 'Идёт запись';

  @override
  String get cameraRecordingNoSound => 'Без звука: нет доступа к микрофону';

  @override
  String get errorRecordingFailed => 'Не удалось записать видео.';

  @override
  String get videoResultTitle => 'Видео';

  @override
  String get videoSaveToGallery => 'Сохранить в галерею';

  @override
  String get videoSavedToGallery => 'Сохранено в галерею';

  @override
  String get videoSaveFailed => 'Не удалось сохранить в галерею. Проверьте доступ к фото в настройках.';

  @override
  String get videoNotFound => 'Это видео больше недоступно.';

  @override
  String get videoPlay => 'Воспроизвести';

  @override
  String get videoPause => 'Пауза';

  @override
  String get videoEdit => 'Редактировать видео';

  @override
  String get videoSilent => 'Записано без звука';

  @override
  String get errorExportCancelled => 'Экспорт отменён.';

  @override
  String get videoEditorTitle => 'Редактор видео';

  @override
  String get videoExport => 'Экспорт';

  @override
  String videoExporting(int percent) {
    return 'Экспорт… $percent%';
  }

  @override
  String get videoExportFailed => 'Не удалось экспортировать видео.';

  @override
  String get videoToolTrim => 'Обрезка';

  @override
  String get videoToolSpeed => 'Скорость';

  @override
  String get videoToolLook => 'Образ';

  @override
  String get videoToolText => 'Текст';

  @override
  String get videoToolStickers => 'Стикеры';

  @override
  String get videoToolMusic => 'Музыка';

  @override
  String get videoAddClip => 'Добавить клип';

  @override
  String get videoRemoveClip => 'Удалить клип';

  @override
  String get videoSpeedMutes => 'Клипы с другой скоростью звучат без собственного звука; музыка остаётся.';

  @override
  String get videoApplyBeauty => 'Бьюти для лиц';

  @override
  String get videoApplyBeautyHint => 'Если выключить, останутся только фильтр и резкость.';

  @override
  String get videoLookPreview => 'Предпросмотр образа (один кадр)';

  @override
  String get videoAddText => 'Добавить текст';

  @override
  String get videoTextDialogTitle => 'Текст';

  @override
  String get videoTextHint => 'Ваш текст';

  @override
  String get videoOverlayTime => 'Показывать';

  @override
  String get videoOverlayDelete => 'Удалить';

  @override
  String get videoOverlayHint => 'Нажмите, чтобы выбрать; перетаскивайте; щипок меняет размер и поворот.';

  @override
  String get videoMusicPick => 'Выбрать';

  @override
  String get videoMusicNone => 'Без музыки';

  @override
  String get videoMusicSelected => 'Музыка добавлена (повтор, затухание)';

  @override
  String get videoMusicRemove => 'Убрать музыку';

  @override
  String get videoMusicVolume => 'Музыка';

  @override
  String get videoOriginalVolume => 'Звук клипа';

  @override
  String get videoImportFailed => 'Не удалось импортировать это видео.';

  @override
  String get projectsPhotosTab => 'Фото';

  @override
  String get projectsVideosTab => 'Видео';

  @override
  String get projectsNewVideo => 'Новое видео';

  @override
  String get projectsVideoEmptyBody => 'Импортируйте видео или снимите его камерой. Оригинал не изменяется.';

  @override
  String get templatesTitle => 'Шаблоны';

  @override
  String get templatesSave => 'Сохранить';

  @override
  String get templatesSlotHint => 'Перетащите фото, щипком — масштаб.';

  @override
  String get templatesReplace => 'Заменить';

  @override
  String get templatesBackground => 'Фон';

  @override
  String get templatesSpacing => 'Отступы';

  @override
  String get templatesCorners => 'Скругление';

  @override
  String get templatesCaptionHint => 'Подпись (необязательно)';

  @override
  String get statusBlocked => 'Заблокировано';

  @override
  String featureBlockedBody(String feature) {
    return '$feature требует сервиса генеративной AI-модели (платный API или GPU-серверы). Функция будет включена после утверждения сервиса. До этого ничего не списывается.';
  }

  @override
  String get errorNetwork => 'Нет связи с сервером. Проверьте интернет и повторите попытку.';

  @override
  String get errorTimeout => 'Сервер слишком долго не отвечал. Повторите попытку.';

  @override
  String get errorSessionExpired => 'Сеанс завершён. Войдите снова.';

  @override
  String get errorInvalidCredentials => 'Неверный email или пароль.';

  @override
  String get errorEmailTaken => 'Аккаунт с этим email уже существует.';

  @override
  String get errorRateLimited => 'Слишком много попыток. Подождите минуту и повторите.';

  @override
  String get errorInvalidPassword => 'Неверный пароль.';

  @override
  String get errorInsufficientCredits => 'Недостаточно кредитов.';

  @override
  String get errorConsentRequired => 'Сначала разрешите облачную AI-обработку.';

  @override
  String get errorAiUnavailable => 'Эта AI-функция сейчас недоступна на сервере. Кредиты не списаны.';

  @override
  String get errorUnsupportedImage => 'Этот формат фото не поддерживается. Используйте JPEG или PNG.';

  @override
  String get errorImageTooLarge => 'Фото слишком большое.';

  @override
  String get errorNoPerson => 'На фото не найден человек. Выберите фото, где человек хорошо виден. Кредиты возвращены.';

  @override
  String get errorProcessingTimeout => 'Обработка занимает больше времени, чем обычно. Повторите позже.';

  @override
  String get errorJobCancelled => 'Задание отменено. Кредиты возвращены.';

  @override
  String get errorProcessingFailed => 'Обработка не удалась. Кредиты возвращены.';

  @override
  String get errorFile => 'Не удалось прочитать или сохранить фото на устройстве.';

  @override
  String get errorServer => 'На сервере произошла ошибка. Повторите позже.';

  @override
  String get accountTitle => 'Аккаунт';

  @override
  String get accountUnconfiguredTitle => 'В этой сборке аккаунты недоступны';

  @override
  String get accountUnconfiguredBody =>
      'Эта сборка не подключена к серверу Yuz. Камера, редактирование и все эффекты на устройстве работают без аккаунта.';

  @override
  String get accountSignedOutBody => 'Войдите, чтобы пользоваться облачными AI-функциями и сохранять кредиты.';

  @override
  String get accountSignIn => 'Войти';

  @override
  String get accountCreate => 'Создать аккаунт';

  @override
  String get accountLoadFailed => 'Не удалось загрузить аккаунт.';

  @override
  String accountCredits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кредитов',
      few: '$count кредита',
      one: '$count кредит',
    );
    return '$_temp0';
  }

  @override
  String accountPremiumActive(String date) {
    return 'Premium до $date';
  }

  @override
  String get accountPremiumInactive => 'Premium не активен';

  @override
  String get accountStore => 'Кредиты и Premium';

  @override
  String get accountCloudAi => 'Облачная AI-обработка';

  @override
  String get accountCloudAiOn => 'Разрешено. Фото, отправленные в AI-функции, обрабатываются на серверах Yuz.';

  @override
  String get accountCloudAiOff => 'Не разрешено. Ничего не загружается.';

  @override
  String get accountRevokeTitle => 'Отключить облачную AI-обработку?';

  @override
  String get accountRevokeBody => 'Задания в очереди будут отменены с возвратом кредитов, загруженные фото удалены.';

  @override
  String get accountRevokeConfirm => 'Отключить';

  @override
  String get accountDisplayName => 'Отображаемое имя';

  @override
  String get accountExport => 'Скачать мои данные';

  @override
  String get accountExportDone => 'Ваши данные сохранены.';

  @override
  String get accountSignOut => 'Выйти';

  @override
  String get accountDelete => 'Удалить аккаунт';

  @override
  String get accountDeleteBody =>
      'Аккаунт, кредиты, AI-задания и загруженные фото будут удалены навсегда. Проекты на телефоне останутся. Введите пароль для подтверждения.';

  @override
  String get accountDeleteConfirm => 'Удалить навсегда';

  @override
  String get accountDeleted => 'Ваш аккаунт удалён.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Пароль';

  @override
  String get authPasswordHint => 'Не менее 10 символов';

  @override
  String get authName => 'Имя (необязательно)';

  @override
  String get authEmailInvalid => 'Введите корректный email';

  @override
  String get authPasswordShort => 'Используйте не менее 10 символов';

  @override
  String get authPasswordRequired => 'Введите пароль';

  @override
  String get authShowPassword => 'Показать пароль';

  @override
  String get authHidePassword => 'Скрыть пароль';

  @override
  String get authSwitchToRegister => 'Нет аккаунта? Создайте';

  @override
  String get authSwitchToSignIn => 'Уже есть аккаунт? Войдите';

  @override
  String get authSecurityNote =>
      'Пароль передаётся только по зашифрованному соединению и хранится как хеш с солью, а не текстом.';

  @override
  String get consentIntro =>
      'AI-функции, например замена фона, работают на серверах Yuz. Прежде чем что-то загрузить, узнайте, что именно происходит:';

  @override
  String get consentPointUpload => 'Загружается только фото, выбранное для AI-функции, по зашифрованному соединению.';

  @override
  String get consentPointDelete =>
      'Загруженное фото удаляется с сервера сразу после обработки. Результат удаляется, как только попадёт на телефон; остатки очищаются автоматически.';

  @override
  String get consentPointUse =>
      'Фото используются только для вашего результата — никогда для рекламы и обучения моделей.';

  @override
  String get consentPointPeople => 'Загружайте только свои фото или фото людей, которые согласились.';

  @override
  String get consentPointLocal =>
      'Бьюти-камера, ретушь и фильтры полностью работают на телефоне и без этого разрешения.';

  @override
  String get consentPointRevoke => 'Разрешение можно отозвать в любой момент в разделе «Аккаунт».';

  @override
  String get consentAccept => 'Разрешить облачную AI';

  @override
  String get consentDecline => 'Не сейчас';

  @override
  String consentVersion(String version) {
    return 'Версия согласия $version';
  }

  @override
  String get storeBalance => 'Баланс';

  @override
  String get storeBlockedTitle => 'Покупки пока не включены';

  @override
  String get storeBlockedBody =>
      'Для покупки кредитов и Premium нужно настроить продукты App Store и Google Play и их проверку на сервере. До этого никаких списаний не будет.';

  @override
  String storePremium(int days) {
    return 'Premium · $days дн.';
  }

  @override
  String get storeUnavailable => 'Недоступно';

  @override
  String get storePrices => 'Цены AI';

  @override
  String get storeHistory => 'История';

  @override
  String get storeHistoryEmpty => 'Операций с кредитами пока нет.';

  @override
  String get creditKindWelcome => 'Приветственный бонус';

  @override
  String get creditKindPurchase => 'Покупка';

  @override
  String get creditKindSpend => 'AI-обработка';

  @override
  String get creditKindRefund => 'Возврат';

  @override
  String get creditKindAdjustment => 'Корректировка';

  @override
  String get aiBgIntro => 'Размойте, перекрасьте или удалите фон за людьми. Обработка на серверах Yuz.';

  @override
  String get aiPickGallery => 'Выбрать фото';

  @override
  String get aiPickCamera => 'Сделать фото';

  @override
  String get aiPickHint => 'Выберите фото с человеком';

  @override
  String get aiModeBlur => 'Размытие';

  @override
  String get aiModeColor => 'Цвет';

  @override
  String get aiModeRemove => 'Удалить';

  @override
  String aiStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Обработать · $count кредитов',
      few: 'Обработать · $count кредита',
      one: 'Обработать · $count кредит',
    );
    return '$_temp0';
  }

  @override
  String aiBalance(int count) {
    return 'Баланс: $count';
  }

  @override
  String get aiStageUploading => 'Загрузка…';

  @override
  String get aiStageQueued => 'Ожидание в очереди…';

  @override
  String get aiStageRunning => 'Обработка…';

  @override
  String get aiStageDownloading => 'Загрузка результата…';

  @override
  String get aiViewOriginal => 'Оригинал';

  @override
  String get aiViewResult => 'Результат';

  @override
  String get aiOpenEditor => 'Редактировать в Yuz';

  @override
  String get aiSignInRequired => 'Войдите, чтобы пользоваться AI-фоном.';

  @override
  String get aiConsentRequired => 'Разрешите облачную AI-обработку, чтобы продолжить.';

  @override
  String get aiReviewConsent => 'Ознакомиться и разрешить';

  @override
  String get aiPrivacyNote => 'Загружается только это фото. После обработки оно удаляется с сервера.';

  @override
  String get helpIntro => 'Ответы на частые вопросы.';

  @override
  String get helpUploadQ => 'Мои фото загружаются?';

  @override
  String get helpUploadA =>
      'Нет. Бьюти-камера, ретушь, фильтры, стикеры, шаблоны и видеоредактор полностью работают на телефоне. Фото покидает телефон, только когда вы используете облачную AI-функцию и разрешили это.';

  @override
  String get helpCreditsQ => 'Что такое кредиты?';

  @override
  String get helpCreditsA =>
      'Облачные AI-функции используют вычисления на сервере и стоят кредитов. Новые аккаунты получают бесплатные приветственные кредиты. Если обработка не удалась, кредиты возвращаются автоматически.';

  @override
  String get helpBlockedQ => 'Почему некоторые AI-функции недоступны?';

  @override
  String get helpBlockedA =>
      'AI-фотосессии, причёскам и макияжу нужен сервис генеративной модели, который ещё не включён. Они помечены как заблокированные и никогда не списывают кредиты.';

  @override
  String get helpDeleteQ => 'Как удалить мои данные?';

  @override
  String get helpDeleteA =>
      'Проекты хранятся на телефоне — удаляйте их в разделе «Проекты». Аккаунт и всё на сервере удаляются в «Аккаунт → Удалить аккаунт». Сначала можно скачать копию через «Скачать мои данные».';

  @override
  String get helpCameraQ => 'Камера показывает чёрный экран';

  @override
  String get helpCameraA =>
      'Проверьте, что доступ к камере разрешён в настройках системы, и закройте другие приложения, использующие камеру.';

  @override
  String get helpSavedQ => 'Где мои сохранённые фото и видео?';

  @override
  String get helpSavedA => 'В галерее телефона, в альбоме «Yuz». Неэкспортированные проекты остаются в приложении.';
}
